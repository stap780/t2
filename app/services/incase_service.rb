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
        
        # Групповая отправка писем для всех созданных убытков
        if @created_incases.any?
          begin
            IncaseEmailService.send(@created_incases)
          rescue => e
            Rails.logger.error "Failed to send grouped emails for import #{@incase_import.id}: #{e.message}"
            # Не прерываем процесс импорта из-за ошибки отправки
          end
        end
      else
        # Формируем информативное сообщение об ошибках с номерами строк
        error_rows = @errors.map { |e| e['row'] || e[:row] }.compact.sort
        rows_info = if error_rows.count <= 10
          "строки: #{error_rows.join(', ')}"
        else
          "строки: #{error_rows.first(10).join(', ')} и еще #{error_rows.count - 10}"
        end
        
        error_message = "Ошибки в #{@failed_count} строках (#{rows_info})"
        
        @incase_import.update!(
          status: @success_count > 0 ? 'completed' : 'failed',
          error_message: error_message,
          import_errors: @errors,
          success_count: @success_count,
          failed_count: @failed_count,
          imported_at: Time.current
        )
        
        # Групповая отправка писем для всех созданных убытков (даже если были ошибки)
        if @created_incases.any?
          begin
            IncaseEmailService.send(@created_incases)
          rescue => e
            Rails.logger.error "Failed to send grouped emails for import #{@incase_import.id}: #{e.message}"
            # Не прерываем процесс импорта из-за ошибки отправки
          end
        end
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
      Roo::CSV.new(file_path, csv_options: {col_sep: ","})
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
      @errors << {'row' => index, 'unumber' => row['Номер дела']&.to_s&.strip, 'errors' => validation_errors}
      @failed_count += 1
      return
    end
    
    unumber = row['Номер дела']&.to_s&.strip
    return if unumber.blank?
    stoanumber = row['Номер З/Н СТОА']&.to_s&.strip

    begin
      # Поиск/создание компаний
      strah_company = find_or_create_company(row['Страховая компания']&.to_s&.strip, 'strah')
      company = find_or_create_company(row['Контрагент']&.to_s&.strip, 'standart')

      # Поиск существующего убытка по паре (unumber + stoanumber)
      existing_incase = Incase.find_by_unumber_and_stoanumber(unumber, stoanumber)

      if existing_incase.present?
        # Проверка на дату для создания вторых и так далее деталей убытка (как в carpats)
        parsed_date = parse_date(row['Дата выкладки Акта п-п в папку СК'])

        if parsed_date.to_date == existing_incase.date.to_date
          # Дата совпадает - добавляем позицию в существующий убыток
          add_item_if_not_exists(existing_incase, row)
          @success_count += 1
        else
          # Дата не совпадает
          if avilon_ag?(company)
            apply_avilon_ag_logic(existing_incase, row, strah_company, company)
          else
            create_incase_dubl(row, strah_company, company)
          end
          @success_count += 1
        end
      else
        # Убыток не существует - создаем новый
        create_new_incase(row, strah_company, company)
        @success_count += 1
      end
    rescue => e
      @errors << {'row' => index, 'unumber' => unumber, 'errors' => ["#{e.class}: #{e.message}"]}
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
    
    # Преобразуем в строку на случай, если пришло число
    title_str = title.to_s.strip
    
    # Company использует short_title для уникальности
    Company.find_or_create_by(short_title: title_str, tip: tip) do |c|
      c.title = title_str
    end
  end
  
  
  def create_incase_dubl(row_data, strah_company, company)
    parsed_date = parse_date(row_data['Дата выкладки Акта п-п в папку СК'])
    modelauto = "#{row_data['Марка ТС']&.to_s} #{row_data['Модель ТС']&.to_s}".strip
    unumber = row_data['Номер дела']&.to_s&.strip
    stoanumber = row_data['Номер З/Н СТОА']&.to_s&.strip
    title = row_data['Деталь']&.to_s&.strip
    katnumber = row_data['Каталожный_номер']&.to_s&.strip
    
    # Ищем существующий дубль по unumber и stoanumber (как в carpats)
    incase_dubls = @incase_import.incase_dubls.where(unumber: unumber, stoanumber: stoanumber)
    
    if incase_dubls.present?
      # Дубль есть - добавляем позицию к каждому дублю (как в carpats)
      incase_dubls.each do |icd|
        # Проверяем позицию по title и katnumber (как в carpats - detalname и katnumber)
        existing_item = icd.incase_item_dubls.where(title: title, katnumber: katnumber).first
        unless existing_item
          icd.incase_item_dubls.create!(
            title: title,
            quantity: parse_integer(row_data['Кол-во']) || 1,
            price: parse_decimal(row_data['Сумма запчастей']) || 0,
            katnumber: katnumber,
            supplier_code: row_data['Код поставщика']&.to_s&.strip
          )
        end
      end
      incase_dubls.first
    else
      # Дубля нет - создаем новый дубль (как в carpats)
      incase_dubl = @incase_import.incase_dubls.create!(
        region: row_data['Регион']&.to_s&.strip,
        strah_id: strah_company.id,
        stoanumber: stoanumber,
        unumber: unumber,
        company_id: company.id,
        carnumber: row_data['Гос номер']&.to_s&.strip,
        date: parsed_date,
        modelauto: modelauto,
        totalsum: parse_decimal(row_data['Сумма заказ наряда'])
      )
      
      # Создаем первую позицию для дубля
      incase_dubl.incase_item_dubls.create!(
        title: title,
        quantity: parse_integer(row_data['Кол-во']) || 1,
        price: parse_decimal(row_data['Сумма запчастей']) || 0,
        katnumber: katnumber,
        supplier_code: row_data['Код поставщика']&.to_s&.strip
      )
      
      incase_dubl
    end
  end
  
  def add_item_if_not_exists(incase, row_data)
    title = row_data['Деталь']&.to_s&.strip
    katnumber = row_data['Каталожный_номер']&.to_s&.strip

    # Проверяем позицию по title и katnumber (как в carpats - detalname и katnumber)
    existing_item = incase.items.where(title: title, katnumber: katnumber).first
    return if existing_item.present?

    # Создать новую позицию (автоматически создастся Product и Variant)
    incase.items.create!(
      title: title,
      quantity: parse_integer(row_data['Кол-во']) || 1,
      price: parse_decimal(row_data['Сумма запчастей']) || 0,
      katnumber: katnumber,
      supplier_code: row_data['Код поставщика']&.to_s&.strip
    )
  end

  AVILON_AG_SHORT_TITLE = 'Авилон АГ'

  def avilon_ag?(company)
    company&.short_title == AVILON_AG_SHORT_TITLE
  end

  # Логика для станции «Авилон АГ» при импорте дублирующего убытка (другая дата).
  # 1) Оба без суммы: новые детали добавляем; дублирующие — статус «Долг», кроме «Да»/«В работе».
  # 2) Убыток без суммы, дубль с суммой: вносим сумму и дату из дубля; новые детали добавляем; дублирующие не трогаем.
  # 3) Убыток с суммой, дубль без суммы: дублирующим ставим «Долг», кроме «Да»/«В работе»; дату и сумму не трогаем.
  # 4) Оба с суммой: обычный дубль (create_incase_dubl).
  def apply_avilon_ag_logic(existing_incase, row, strah_company, company)
    incase_has_sum = existing_incase.totalsum.to_f.positive?
    dubl_sum = parse_decimal(row['Сумма заказ наряда'])
    dubl_has_sum = dubl_sum.to_f.positive?
    katnumber = row['Каталожный_номер']&.to_s&.strip
    duplicate_items = existing_incase.items.includes(:item_status).where(katnumber: katnumber).to_a

    dolg_status = ItemStatus.find_by(title: 'Долг')
    skip_status_titles = %w[Да В работе]

    if !incase_has_sum && !dubl_has_sum
      # 1) Оба без суммы
      add_item_if_not_exists(existing_incase, row)
      set_duplicate_items_to_dolg(existing_incase, duplicate_items, dolg_status, skip_status_titles)
    elsif !incase_has_sum && dubl_has_sum
      # 2) Убыток без суммы, дубль с суммой
      parsed_date = parse_date(row['Дата выкладки Акта п-п в папку СК'])
      existing_incase.update!(totalsum: dubl_sum, date: parsed_date)
      add_item_if_not_exists(existing_incase, row)
    elsif incase_has_sum && !dubl_has_sum
      # 3) Убыток с суммой, дубль без суммы
      set_duplicate_items_to_dolg(existing_incase, duplicate_items, dolg_status, skip_status_titles)
    else
      # 4) Оба с суммой — обычный дубль
      create_incase_dubl(row, strah_company, company)
    end
  end

  def set_duplicate_items_to_dolg(existing_incase, duplicate_items, dolg_status, skip_status_titles)
    return if dolg_status.blank?
    duplicate_items.each do |item|
      next if item.item_status.blank?
      next if skip_status_titles.include?(item.item_status.title)
      item.update!(item_status_id: dolg_status.id)
    end
  end
  
  def create_new_incase(row_data, strah_company, company)
    parsed_date = parse_date(row_data['Дата выкладки Акта п-п в папку СК'])
    modelauto = "#{row_data['Марка ТС']&.to_s} #{row_data['Модель ТС']&.to_s}".strip
    
    # Создаем убыток с позицией через accepts_nested_attributes_for
    # чтобы валидация items_presence прошла успешно
    incase = Incase.new(
      region: row_data['Регион']&.to_s&.strip,
      strah_id: strah_company.id,
      stoanumber: row_data['Номер З/Н СТОА']&.to_s&.strip,
      unumber: row_data['Номер дела']&.to_s&.strip,
      company_id: company.id,
      carnumber: row_data['Гос номер']&.to_s&.strip,
      date: parsed_date,
      modelauto: modelauto,
      totalsum: parse_decimal(row_data['Сумма заказ наряда']),
      items_attributes: {
        '0' => {
          title: row_data['Деталь']&.to_s&.strip,
          quantity: parse_integer(row_data['Кол-во']) || 1,
          price: parse_decimal(row_data['Сумма запчастей']) || 0,
          katnumber: row_data['Каталожный_номер']&.to_s&.strip,
          supplier_code: row_data['Код поставщика']&.to_s&.strip
        }
      }
    )
    
    incase.save!
    
    @created_incases << incase.id
    
    # Отправка писем будет выполнена групповым образом после завершения импорта
    
    incase
  end
  
  def parse_date(date_string)
    return nil if date_string.blank?
    
    # Пробуем разные форматы даты
    if date_string.is_a?(Date) || date_string.is_a?(Time) || date_string.is_a?(DateTime)
      return date_string.to_date
    end
    
    date_str = date_string.to_s.strip
    
    # Пробуем разные форматы даты
    # 1. MM/DD/YYYY (американский формат, часто используется в CSV)
    if date_str.match?(/^\d{1,2}\/\d{1,2}\/\d{4}$/)
      begin
        return Date.strptime(date_str, '%m/%d/%Y')
      rescue ArgumentError
        # Пробуем DD/MM/YYYY если MM/DD/YYYY не подошел
        begin
          return Date.strptime(date_str, '%d/%m/%Y')
        rescue ArgumentError
          # Продолжаем к другим форматам
        end
      end
    end
    
    # 2. DD.MM.YYYY (европейский формат)
    if date_str.match?(/^\d{1,2}\.\d{1,2}\.\d{4}$/)
      begin
        return Date.strptime(date_str, '%d.%m.%Y')
      rescue ArgumentError
        # Продолжаем к другим форматам
      end
    end
    
    # 3. Стандартный парсинг Ruby (ISO формат и другие)
    begin
      return Date.parse(date_str)
    rescue ArgumentError
      # Пробуем через Time
      begin
        return Time.parse(date_str).to_date
      rescue ArgumentError, TypeError
        raise ArgumentError, "Invalid date format: #{date_string}"
      end
    end
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

