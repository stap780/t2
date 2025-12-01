require 'net/http'
require 'uri'
require 'csv'
require 'open-uri'

class Product::Import
  CSV_URL = 'http://138.197.52.153/exports/products.csv'
  CSV_FILE_PATH = Rails.root.join('..', 'products.csv').to_s
  
  
  # Поля товара
  PRODUCT_FIELDS = %w[name description].freeze
  
  # Поля варианта
  VARIANT_FIELDS = %w[code article sale_price quantity].freeze
  
  
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
      limit = Rails.env.development? ? 100 : rows.count
      rows_to_process = rows.first(limit)
      
      Rails.logger.info "📦 ProductService: Processing #{rows_to_process.count} products (limit: #{limit})"
      
      # Предзагружаем все Properties и Characteristics в память
      preload_properties_and_characteristics
      
      # Обрабатываем все товары асинхронно через Solid Queue
      process_asynchronously(rows_to_process)
      
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
  
  def process_asynchronously(rows)
    # Асинхронная обработка через Solid Queue
    # Отправляем каждый товар отдельно в очередь
    rows.each_with_index do |row, index|
      # Преобразуем CSV::Row в Hash для сериализации
      data = row.to_h
      
      ProductImportBatchJob.perform_later(
        data,
        properties_cache: @properties_cache,
        characteristics_cache: @characteristics_cache
      )
    end
    
    Rails.logger.info "📦 ProductService: Enqueued #{rows.count} product import jobs"
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

