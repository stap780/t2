require 'net/http'
require 'uri'
require 'csv'
require 'open-uri'

class Product::Import
  CSV_URL = 'http://138.197.52.153/exports/products.csv'
  CSV_FILE_PATH = Rails.root.join('..', 'products.csv').to_s
  JOB_BATCH_SIZE = 50
  LOGGER = Logger.new(Rails.root.join("log", "product_import.log"))
  
  
  # Поля товара
  PRODUCT_FIELDS = %w[name description].freeze
  
  # Поля варианта
  VARIANT_FIELDS = %w[code article sale_price quantity].freeze
  
  
  def initialize
    @enqueued_jobs = 0
    @enqueued_products = 0
  end
  
  def call
    if Rails.env.development?
      LOGGER.info "📦 ProductService: Starting import from local file #{CSV_FILE_PATH}"
    else
      LOGGER.info "📦 ProductService: Starting import from #{CSV_URL}"
    end
    
    begin
      @csv_content = load_csv
      rows = parse_csv(@csv_content)
      
      # В development режиме ограничиваем до 100 товаров
      limit = Rails.env.development? ? 100 : 2000 #rows.count
      rows_to_process = rows.first(limit)
      
      LOGGER.info "📦 ProductService: Processing #{rows_to_process.count} products (limit: #{limit})"
      
      # Обрабатываем все товары асинхронно через Solid Queue
      process_asynchronously(rows_to_process)
      
      LOGGER.info "📦 ProductService: Completed. Enqueued #{@enqueued_jobs} jobs for #{@enqueued_products} products"
      
      {
        success: true,
        enqueued_jobs: @enqueued_jobs,
        enqueued_products: @enqueued_products,
        message: "Enqueued #{@enqueued_jobs} jobs for #{@enqueued_products} products. Check job logs for actual created/updated counts."
      }
    rescue => e
      LOGGER.error "📦 ProductService ERROR: #{e.class} - #{e.message}"
      LOGGER.error e.backtrace.join("\n")
      
      {
        success: false,
        error: "#{e.class}: #{e.message}",
        enqueued_jobs: @enqueued_jobs,
        enqueued_products: @enqueued_products
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
    # Группируем строки в батчи, чтобы уменьшить количество job'ов
    total_rows = rows.size
    batch_count = 0

    rows.each_slice(JOB_BATCH_SIZE) do |batch|
      batch_data = batch.map(&:to_h)
      ProductImportBatchJob.perform_later(batch_data)
      batch_count += 1
    end
    
    @enqueued_jobs = batch_count
    @enqueued_products = total_rows
    
    LOGGER.info "📦 ProductService: Enqueued #{batch_count} product import jobs for #{total_rows} products (batch size: #{JOB_BATCH_SIZE})"
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

