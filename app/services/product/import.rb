require 'net/http'
require 'uri'
require 'csv'
require 'open-uri'

class Product::Import
  CSV_URL = 'http://138.197.52.153/exports/products.csv'
  CSV_FILE_PATH = Rails.root.join('..', 'products.csv').to_s
  
  # Пороги для определения стратегии обработки
  SYNC_THRESHOLD = 1000    # Синхронная обработка до 1000 товаров
  SPLIT_THRESHOLD = 10_000 # Разделение CSV при > 10000 товаров
  BATCH_SIZE = 10          # Размер батча для асинхронной обработки
  
  # Поля товара
  PRODUCT_FIELDS = %w[name description].freeze
  
  # Поля варианта
  VARIANT_FIELDS = %w[code article sale_price quantity].freeze
  
  # Поля параметров
  PROPERTY_FIELDS = %w[
    pathname station marka model god detal externalcode dtype diametr shob kotv dotv 
    vilet analog weight stupica sdiameter stype swidth sratio video guaranty material avitocat_file
  ].freeze
  
  def initialize
    @created_count = 0
    @updated_count = 0
    @errors = []
    # Кэш для Properties и Characteristics (избегаем N+1 запросов)
    @properties_cache = {}
    @characteristics_cache = {}
  end
  
  def call
    if Rails.env.development?
      Rails.logger.info "📦 ProductService: Starting import from local file #{CSV_FILE_PATH}"
    else
      Rails.logger.info "📦 ProductService: Starting import from #{CSV_URL}"
    end
    
    begin
      @csv_content = load_csv
      rows = parse_csv(@csv_content)
      
      # В development режиме ограничиваем до 300 товаров
      limit = Rails.env.development? ? 50 : rows.count
      rows_to_process = rows.first(limit)
      
      Rails.logger.info "📦 ProductService: Processing #{rows_to_process.count} products (limit: #{limit})"
      
      # Предзагружаем все Properties и Characteristics в память
      preload_properties_and_characteristics
      
      # Проверяем, нужно ли разделять файл для очень больших объемов
      if rows_to_process.count > SPLIT_THRESHOLD
        # Разделяем CSV на несколько файлов для параллельной обработки
        split_files = split_csv_if_needed
        if split_files.present?
          process_split_files(split_files)
        else
          # Если разделение не удалось, обрабатываем как обычно
          process_rows(rows_to_process)
        end
      else
        # Обычная обработка без разделения
        process_rows(rows_to_process)
      end
      
      Rails.logger.info "📦 ProductService: Completed. Created: #{@created_count}, Updated: #{@updated_count}, Errors: #{@errors.count}"
      
      {
        success: true,
        created: @created_count,
        updated: @updated_count,
        errors: @errors.count,
        error_details: @errors
      }
    rescue => e
      Rails.logger.error "📦 ProductService ERROR: #{e.class} - #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      {
        success: false,
        error: "#{e.class}: #{e.message}",
        created: @created_count,
        updated: @updated_count,
        errors: @errors.count
      }
    end
  end
  
  private
  
  def load_csv
    if Rails.env.development?
      load_from_file
    else
      download_csv
    end
  end
  
  def load_from_file
    unless File.exist?(CSV_FILE_PATH)
      raise "CSV file not found: #{CSV_FILE_PATH}"
    end
    
    File.read(CSV_FILE_PATH)
  end
  
  def download_csv
    uri = URI(CSV_URL)
    
    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)
      
      raise "Failed to download file: #{response.code}" unless response.code == '200'
      
      response.body
    end
  end
  
  def parse_csv(csv_content)
    # Обеспечиваем правильную кодировку
    safe_content = csv_content.force_encoding('UTF-8')
    safe_content = safe_content.scrub('?') unless safe_content.valid_encoding?
    
    CSV.parse(safe_content, headers: true)
  end
  
  def split_csv_if_needed
    # Определяем путь к файлу для разделения
    file_path = if Rails.env.development? && File.exist?(CSV_FILE_PATH)
                  CSV_FILE_PATH
                else
                  # Если файл не существует локально, сохраняем загруженный контент во временный файл
                  temp_file = Rails.root.join('tmp', 'csv_imports', "products-#{Time.now.to_i}.csv").to_s
                  FileUtils.mkdir_p(File.dirname(temp_file))
                  File.write(temp_file, @csv_content || load_csv)
                  temp_file
                end
    
    # Используем SplitCsvFile для разделения
    Product::SplitCsvFile.new(file_path).call
  end
  
  def process_split_files(split_files)
    # Обрабатываем каждый разделенный файл асинхронно
    split_files.each do |file_path|
      Rails.logger.info "📦 ProductService: Processing split file: #{file_path}"
      
      # Парсим разделенный файл
      rows = CSV.parse(File.read(file_path), headers: true)
      
      # Обрабатываем асинхронно
      process_asynchronously(rows)
    end
    
    Rails.logger.info "📦 ProductService: Processing #{split_files.count} split files"
  end
  
  def process_rows(rows)
    # Определяем стратегию обработки
    if rows.count < SYNC_THRESHOLD
      # Синхронная обработка для маленьких объемов
      process_synchronously(rows)
    else
      # Асинхронная обработка для больших объемов
      process_asynchronously(rows)
    end
  end
  
  def process_synchronously(rows)
    # Синхронная обработка для маленьких объемов (< 1000)
    rows.each_slice(BATCH_SIZE) do |batch|
      ActiveRecord::Base.transaction do
        batch.each_with_index do |row, batch_index|
          process_product(row, batch_index + 1)
        end
      end
    end
  end
  
  def process_asynchronously(rows)
    # Асинхронная обработка для больших объемов (>= 1000)
    # Разделяем на батчи и отправляем в очередь
    rows.each_slice(BATCH_SIZE) do |batch|
      # Преобразуем CSV::Row в Hash для сериализации
      batch_data = batch.map(&:to_h)
      
      ProductImportBatchJob.perform_later(
        batch_data,
        properties_cache: @properties_cache,
        characteristics_cache: @characteristics_cache
      )
    end
    
    Rails.logger.info "📦 ProductService: Enqueued #{(rows.count.to_f / BATCH_SIZE).ceil} batch jobs"
  end
  
  def process_product(row, index)
    begin
      data = row.to_h
      result = Product::ImportSaveData.new(
        data,
        properties_cache: @properties_cache,
        characteristics_cache: @characteristics_cache
      ).call
      
      if result[:success]
        # Загружаем изображения асинхронно (не блокируем основной процесс)
        if result[:images_urls].present?
          ProductImageJob.perform_later(result[:product].id, result[:images_urls])
        end
        
        if result[:created]
          @created_count += 1
        else
          @updated_count += 1
        end
        
        Rails.logger.debug "📦 ProductService: Processed product ##{index}: #{result[:product].title}"
      else
        @errors << "Row #{index}: #{result[:error]}"
      end
    rescue => e
      error_msg = "Row #{index}: #{e.class} - #{e.message}"
      Rails.logger.error "📦 ProductService ERROR: #{error_msg}"
      @errors << error_msg
    end
  end
  
  def preload_properties_and_characteristics
    # Предзагружаем все существующие Properties и Characteristics в память
    Property.includes(:characteristics).find_each do |property|
      @properties_cache[property.title] = property
      property.characteristics.each do |characteristic|
        cache_key = "#{property.id}_#{characteristic.title}"
        @characteristics_cache[cache_key] = characteristic
      end
    end
  end
  
  def normalize_text(text)
    return nil if text.blank?
    text.to_s.strip.presence
  end
  
  def parse_decimal(value)
    return nil if value.blank?
    value.to_s.gsub(',', '.').to_f
  rescue
    nil
  end
  
  def parse_integer(value)
    return nil if value.blank?
    value.to_s.to_i
  rescue
    nil
  end
end

