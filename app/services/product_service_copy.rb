require 'net/http'
require 'uri'
require 'csv'
require 'open-uri'

class ProductServiceCopy
  CSV_URL = 'http://138.197.52.153/exports/products.csv'
  CSV_FILE_PATH = Rails.root.join('..', 'products.csv').to_s
  
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
  end
  
  def call
    if Rails.env.development?
      Rails.logger.info "📦 ProductService: Starting import from local file #{CSV_FILE_PATH}"
    else
      Rails.logger.info "📦 ProductService: Starting import from #{CSV_URL}"
    end
    
    begin
      csv_content = load_csv
      rows = parse_csv(csv_content)
      
      # В development режиме ограничиваем до 300 товаров
      limit = Rails.env.development? ? 10 : rows.count
      rows_to_process = rows.first(limit)
      
      Rails.logger.info "📦 ProductService: Processing #{rows_to_process.count} products (limit: #{limit})"
      
      rows_to_process.each_with_index do |row, index|
        process_product(row, index + 1)
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
  
  def process_product(row, index)
    begin
      # Получаем данные товара
      product_data = extract_product_data(row)
      variant_data = extract_variant_data(row)
      properties_data = extract_properties_data(row)
      images_urls = extract_images_urls(row)
      
      # Создаем или находим товар (сначала по штрихкоду варианта, потом по названию)
      product = find_or_create_product(product_data, variant_data)
      
      # Создаем или обновляем вариант
      variant = find_or_create_variant(product, variant_data)
      
      # Создаем параметры
      create_properties(product, properties_data)
      
      # Загружаем изображения
      attach_images(product, images_urls) if images_urls.any?
      
      if product.persisted? && product.previously_new_record?
        @created_count += 1
      else
        @updated_count += 1
      end
      
      Rails.logger.debug "📦 ProductService: Processed product ##{index}: #{product.title}"
    rescue => e
      error_msg = "Row #{index}: #{e.class} - #{e.message}"
      Rails.logger.error "📦 ProductService ERROR: #{error_msg}"
      @errors << error_msg
    end
  end
  
  def extract_product_data(row)
    {
      title: normalize_text(row['name']),
      description: normalize_text(row['description'])
    }
  end
  
  def extract_variant_data(row)
    {
      barcode: normalize_text(row['code']),
      sku: normalize_text(row['article']),
      price: parse_decimal(row['sale_price']),
      quantity: parse_integer(row['quantity']) || 0
    }
  end
  
  def extract_properties_data(row)
    properties = {}
    
    PROPERTY_FIELDS.each do |field|
      value = normalize_text(row[field])
      properties[field] = value if value.present?
    end
    
    properties
  end
  
  def extract_images_urls(row)
    urls_string = normalize_text(row['images_urls'])
    return [] if urls_string.blank?
    
    urls_string.split(',').map(&:strip).reject(&:blank?)
  end
  
  def find_or_create_product(data, variant_data)
    # Сначала ищем товар по штрихкоду варианта (если есть)
    product = nil
    if variant_data[:barcode].present?
      variant = Variant.find_by(barcode: variant_data[:barcode])
      product = variant&.product
    end
    
    # Если не нашли по штрихкоду, ищем по артикулу варианта
    if product.nil? && variant_data[:sku].present?
      variant = Variant.find_by(sku: variant_data[:sku])
      product = variant&.product
    end
    
    # Если не нашли по варианту, ищем по названию товара
    if product.nil? && data[:title].present?
      product = Product.find_by(title: data[:title])
    end
    
    if product
      # Обновляем описание, если оно изменилось
      if data[:description].present? && product.description.to_plain_text != data[:description]
        product.update(description: data[:description])
      end
      product
    else
      # Создаем новый товар только если есть название
      return nil if data[:title].blank?
      
      Product.create!(
        title: data[:title],
        description: data[:description],
        status: 'draft',
        tip: 'product'
      )
    end
  end
  
  def find_or_create_variant(product, data)
    # Ищем вариант по штрихкоду или артикулу
    variant = if data[:barcode].present?
                product.variants.find_by(barcode: data[:barcode])
              elsif data[:sku].present?
                product.variants.find_by(sku: data[:sku])
              else
                nil
              end
    
    if variant
      # Обновляем данные варианта
      variant.update!(
        barcode: data[:barcode] || variant.barcode,
        sku: data[:sku] || variant.sku,
        price: data[:price] || variant.price,
        quantity: data[:quantity] || variant.quantity
      )
      variant
    else
      # Создаем новый вариант
      product.variants.create!(
        barcode: data[:barcode],
        sku: data[:sku],
        price: data[:price] || 0,
        quantity: data[:quantity] || 0
      )
    end
  end
  
  def create_properties(product, properties_data)
    properties_data.each do |property_title, characteristic_value|
      next if characteristic_value.blank?
      
      # Находим или создаем Property
      property = Property.find_or_create_by!(title: property_title.to_s)
      
      # Находим или создаем Characteristic для этого Property
      characteristic = property.characteristics.find_or_create_by!(
        title: characteristic_value.to_s
      )
      
      # Создаем или находим Feature (связь Product -> Property -> Characteristic)
      feature = product.features.find_or_initialize_by(property: property)
      feature.characteristic = characteristic
      feature.save! if feature.changed?
    end
  end
  
  def attach_images(product, image_urls)
    return if image_urls.empty?
    
    image_urls.each_with_index do |url, index|
      next if url.blank?
      
      begin
        # Парсим URL
        uri = URI.parse(url)
        filename = File.basename(uri.path)
        content_type = determine_content_type(filename)
        
        # Пропускаем неподдерживаемые форматы (Image модель принимает только JPEG и PNG)
        unless ['image/jpeg', 'image/png'].include?(content_type)
          Rails.logger.warn "📦 ProductService: Skipping unsupported image format: #{filename} (#{content_type})"
          next
        end
        
        # Проверяем, не загружено ли уже это изображение
        existing_image = product.images.joins(:file_attachment)
                                 .joins("INNER JOIN active_storage_blobs ON active_storage_blobs.id = active_storage_attachments.blob_id")
                                 .where("active_storage_blobs.filename = ?", filename)
                                 .first
        
        next if existing_image.present?
        
        # Загружаем изображение
        downloaded_file = URI.open(url, read_timeout: 10)
        
        # Создаем Image с прикрепленным файлом
        image = product.images.build(position: product.images.count + 1)
        image.file.attach(
          io: downloaded_file,
          filename: filename,
          content_type: content_type
        )
        
        if image.save
          Rails.logger.debug "📦 ProductService: Attached image #{index + 1}/#{image_urls.count} to product #{product.id}"
        else
          Rails.logger.warn "📦 ProductService: Failed to save image #{url}: #{image.errors.full_messages.join(', ')}"
        end
      rescue => e
        Rails.logger.warn "📦 ProductService: Failed to attach image #{url}: #{e.message}"
        # Продолжаем обработку других изображений
      end
    end
  end
  
  def determine_content_type(filename)
    ext = File.extname(filename).downcase
    case ext
    when '.jpg', '.jpeg'
      'image/jpeg'
    when '.png'
      'image/png'
    else
      'image/jpeg' # По умолчанию (Image модель принимает только JPEG и PNG)
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

