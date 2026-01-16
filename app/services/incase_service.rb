class IncaseService
  attr_reader :incase_import, :errors, :success_count, :failed_count, :created_incases
  
  def initialize(incase_import)
    @incase_import = incase_import
    @errors = []
    @success_count = 0
    @failed_count = 0
    @created_incases = []
  end
  
  def call
    @incase_import.update!(status: 'processing')
    
    begin
      rows = parse_file
      @incase_import.update!(total_rows: rows.count)
      
      process_rows(rows)
      
      if @errors.empty?
        @incase_import.update!(
          status: 'completed',
          imported_at: Time.current,
          success_count: @success_count,
          failed_count: @failed_count
        )
      else
        @incase_import.update!(
          status: @success_count > 0 ? 'completed' : 'failed',
          error_message: "Ошибки в #{@failed_count} строках",
          import_errors: @errors,
          success_count: @success_count,
          failed_count: @failed_count,
          imported_at: Time.current
        )
      end
    rescue => e
      Rails.logger.error "IncaseService ERROR: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      @incase_import.update!(
        status: 'failed',
        error_message: "#{e.class}: #{e.message}",
        imported_at: Time.current
      )
    end
  end
  
  private
  
  def parse_file
    blob = @incase_import.file.blob
    
    # Используем blob.open для работы с файлом (работает для S3 и локального хранилища)
    blob.open do |tempfile|
      spreadsheet = open_spreadsheet(tempfile.path, blob.filename.to_s)
      
      header = spreadsheet.row(1)
      rows = (2..spreadsheet.last_row).map do |i|
        Hash[[header, spreadsheet.row(i)].transpose]
      end
      rows
    end
  end
  
  def open_spreadsheet(file_path, filename)
    case File.extname(filename).downcase
    when ".csv" 
      Roo::CSV.new(file_path, csv_options: {col_sep: ";"})
    when ".xls" 
      Roo::Excel.new(file_path)
    when ".xlsx" 
      Roo::Excelx.new(file_path)
    else 
      raise "Unknown file type: #{filename}. Supported formats: CSV, XLS, XLSX"
    end
  end
  
  def process_rows(rows)
    rows.each_with_index do |row, index|
      process_row(row, index + 2) # +2 потому что первая строка - заголовок
    end
  end
  
  def process_row(row, index)
    # Валидация строки
    validation_errors = validate_row(row, index)
    if validation_errors.any?
      @errors << {row: index, unumber: row['Номер дела']&.strip, errors: validation_errors}
      @failed_count += 1
      return
    end
    
    unumber = row['Номер дела']&.strip
    return if unumber.blank?
    
    begin
      # Поиск/создание компаний
      strah_company = find_or_create_company(row['Страховая компания']&.strip, 'strah')
      company = find_or_create_company(row['Контрагент']&.strip, 'standart')
      
      # Поиск существующего убытка
      existing_incase = Incase.find_by(unumber: unumber)
      
      if existing_incase.present?
        # Проверка отличий
        if has_differences?(existing_incase, row, strah_company, company)
          # Есть отличия - создаем дубль
          create_incase_dubl(row, strah_company, company)
          @success_count += 1
        else
          # Все совпадает - добавляем позицию, если её нет
          add_item_if_not_exists(existing_incase, row)
          @success_count += 1
        end
      else
        # Убыток не существует - создаем новый
        create_new_incase(row, strah_company, company)
        @success_count += 1
      end
    rescue => e
      @errors << {row: index, unumber: unumber, errors: ["#{e.class}: #{e.message}"]}
      @failed_count += 1
      Rails.logger.error "Error processing row #{index}: #{e.message}"
    end
  end
  
  def validate_row(row, index)
    errors = []
    
    errors << "Номер дела обязателен" if row['Номер дела'].blank?
    errors << "Дата обязательна" if row['Дата выкладки Акта п-п в папку СК'].blank?
    errors << "Контрагент обязателен" if row['Контрагент'].blank?
    errors << "Страховая компания обязательна" if row['Страховая компания'].blank?
    
    # Валидация формата даты
    if row['Дата выкладки Акта п-п в папку СК'].present?
      begin
        parse_date(row['Дата выкладки Акта п-п в папку СК'])
      rescue ArgumentError, TypeError
        errors << "Неверный формат даты"
      end
    end
    
    errors
  end
  
  def find_or_create_company(title, tip)
    return nil if title.blank?
    
    # Company использует short_title для уникальности
    Company.find_or_create_by(short_title: title.strip, tip: tip) do |c|
      c.title = title.strip
    end
  end
  
  def has_differences?(existing_incase, row_data, strah_company, company)
    parsed_date = parse_date(row_data['Дата выкладки Акта п-п в папку СК'])
    modelauto = "#{row_data['Марка ТС']} #{row_data['Модель ТС']}".strip
    
    existing_incase.date != parsed_date ||
    existing_incase.stoanumber != row_data['Номер З/Н СТОА']&.strip ||
    existing_incase.company_id != company.id ||
    existing_incase.strah_id != strah_company.id ||
    existing_incase.carnumber != row_data['Гос номер']&.strip ||
    existing_incase.modelauto != modelauto ||
    existing_incase.region != row_data['Регион']&.strip
  end
  
  def create_incase_dubl(row_data, strah_company, company)
    parsed_date = parse_date(row_data['Дата выкладки Акта п-п в папку СК'])
    modelauto = "#{row_data['Марка ТС']} #{row_data['Модель ТС']}".strip
    unumber = row_data['Номер дела']&.strip
    
    # Ищем существующий дубль для этого unumber в текущем импорте
    incase_dubl = @incase_import.incase_dubls.find_by(unumber: unumber)
    
    if incase_dubl.nil?
      # Создаем новый дубль только если его еще нет
      incase_dubl = @incase_import.incase_dubls.create!(
        region: row_data['Регион']&.strip,
        strah_id: strah_company.id,
        stoanumber: row_data['Номер З/Н СТОА']&.strip,
        unumber: unumber,
        company_id: company.id,
        carnumber: row_data['Гос номер']&.strip,
        date: parsed_date,
        modelauto: modelauto,
        totalsum: parse_decimal(row_data['Сумма заказ наряда'])
      )
    end
    
    # Добавляем позицию к дублю (проверяем, чтобы не дублировать позиции)
    katnumber = row_data['Каталожный_номер']&.strip
    existing_item = incase_dubl.incase_item_dubls.find_by(katnumber: katnumber) if katnumber.present?
    
    unless existing_item
      incase_dubl.incase_item_dubls.create!(
        title: row_data['Деталь']&.strip,
        quantity: parse_integer(row_data['Кол-во']) || 1,
        price: parse_decimal(row_data['Сумма запчастей']) || 0,
        katnumber: katnumber,
        supplier_code: row_data['Код поставщика']&.strip
      )
    end
    
    incase_dubl
  end
  
  def add_item_if_not_exists(incase, row_data)
    katnumber = row_data['Каталожный_номер']&.strip
    return if katnumber.blank?
    
    existing_item = incase.items.find_by(katnumber: katnumber)
    return if existing_item.present?
    
    # Создать новую позицию (автоматически создастся Product и Variant)
    incase.items.create!(
      title: row_data['Деталь']&.strip,
      quantity: parse_integer(row_data['Кол-во']) || 1,
      price: parse_decimal(row_data['Сумма запчастей']) || 0,
      katnumber: katnumber,
      supplier_code: row_data['Код поставщика']&.strip
    )
  end
  
  def create_new_incase(row_data, strah_company, company)
    parsed_date = parse_date(row_data['Дата выкладки Акта п-п в папку СК'])
    modelauto = "#{row_data['Марка ТС']} #{row_data['Модель ТС']}".strip
    
    incase = Incase.create!(
      region: row_data['Регион']&.strip,
      strah_id: strah_company.id,
      stoanumber: row_data['Номер З/Н СТОА']&.strip,
      unumber: row_data['Номер дела']&.strip,
      company_id: company.id,
      carnumber: row_data['Гос номер']&.strip,
      date: parsed_date,
      modelauto: modelauto
    )
    
    # Создать первую позицию (автоматически создастся Product и Variant)
    incase.items.create!(
      title: row_data['Деталь']&.strip,
      quantity: parse_integer(row_data['Кол-во']) || 1,
      price: parse_decimal(row_data['Сумма запчастей']) || 0,
      katnumber: row_data['Каталожный_номер']&.strip,
      supplier_code: row_data['Код поставщика']&.strip
    )
    
    @created_incases << incase.id
    
    # Автоматическая отправка письма для нового убытка (Сценарий 3)
    begin
      IncaseEmailService.send_one(incase.id)
    rescue => e
      Rails.logger.error "Failed to auto-send email for incase #{incase.id}: #{e.message}"
      # Не прерываем процесс импорта из-за ошибки отправки
    end
    
    incase
  end
  
  def parse_date(date_string)
    return nil if date_string.blank?
    
    # Пробуем разные форматы даты
    if date_string.is_a?(Date) || date_string.is_a?(Time) || date_string.is_a?(DateTime)
      return date_string.to_date
    end
    
    # Пробуем парсить как строку
    Date.parse(date_string.to_s)
  rescue ArgumentError
    # Если не получилось, пробуем через Time
    Time.parse(date_string.to_s).to_date
  rescue
    raise ArgumentError, "Invalid date format: #{date_string}"
  end
  
  def parse_decimal(value)
    return nil if value.blank?
    return value if value.is_a?(Numeric)
    
    value.to_s.gsub(',', '.').to_f
  end
  
  def parse_integer(value)
    return nil if value.blank?
    return value if value.is_a?(Integer)
    
    value.to_s.to_i
  end
  
end

