require 'open-uri'

class Product::ImportImage
  def initialize(product, image_urls)
    @product = product.is_a?(Product) ? product : Product.find(product)
    @image_urls = Array(image_urls)
  end
  
  def call
    return { success: true, attached: 0 } if @image_urls.empty?
    
    # Предзагрузка существующих изображений
    existing_filenames = @product.images.joins(file_attachment: :blob)
                                 .pluck('active_storage_blobs.filename')
                                 .to_set
    
    attached_count = 0
    
    @image_urls.each_with_index do |url, index|
      next if url.blank?
      
      begin
        result = attach_single_image(url, existing_filenames, index)
        attached_count += 1 if result[:success]
      rescue => e
        Rails.logger.warn "📦 Product::ImportImage: Failed to attach image #{url}: #{e.message}"
      end
    end
    
    {
      success: true,
      attached: attached_count,
      total: @image_urls.count
    }
  rescue => e
    {
      success: false,
      error: "#{e.class}: #{e.message}",
      attached: 0
    }
  end
  
  private
  
  def attach_single_image(url, existing_filenames, index)
    uri = URI.parse(url)
    filename = File.basename(uri.path)
    content_type = determine_content_type(filename)
    
    # Пропускаем неподдерживаемые форматы
    unless ['image/jpeg', 'image/png'].include?(content_type)
      Rails.logger.warn "📦 Product::ImportImage: Skipping unsupported format: #{filename} (#{content_type})"
      return { success: false, reason: 'unsupported_format' }
    end
    
    # Проверяем дубликаты
    if existing_filenames.include?(filename)
      Rails.logger.debug "📦 Product::ImportImage: Image already exists: #{filename}"
      return { success: false, reason: 'duplicate' }
    end
    
    # Загружаем изображение
    downloaded_file = URI.open(url, read_timeout: 10)
    
    # Создаем Image
    image = @product.images.build(position: @product.images.count + 1)
    image.file.attach(
      io: downloaded_file,
      filename: filename,
      content_type: content_type
    )
    
    if image.save
      existing_filenames.add(filename)  # Обновляем кэш
      Rails.logger.debug "📦 Product::ImportImage: Attached image #{index + 1}/#{@image_urls.count} to product #{@product.id}"
      { success: true }
    else
      Rails.logger.warn "📦 Product::ImportImage: Failed to save image: #{image.errors.full_messages.join(', ')}"
      { success: false, reason: 'validation_failed', errors: image.errors.full_messages }
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
      'image/jpeg'  # По умолчанию
    end
  end
end

