require 'open-uri'

class Product::ImportImage
  MAX_CONCURRENT_DOWNLOADS = 5  # Количество одновременных загрузок
  
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
    
    # Вычисляем начальную позицию один раз
    start_position = @product.images.maximum(:position) || 0
    urls_to_process = @image_urls.reject(&:blank?)
    
    # Параллельная загрузка батчами
    results = download_images_in_batches(urls_to_process, existing_filenames, start_position)
    attached_count = results.count { |r| r[:success] }
    
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
  
  def download_images_in_batches(urls, existing_filenames, start_position)
    results = []
    position_mutex = Mutex.new
    position_counter = start_position
    
    urls.each_slice(MAX_CONCURRENT_DOWNLOADS) do |batch|
      threads = batch.map.with_index do |url, batch_index|
        Thread.new do
          position = position_mutex.synchronize { position_counter += 1 }
          attach_single_image(url, existing_filenames, position, batch_index)
        end
      end
      
      threads.each { |t| results << t.value }
    end
    
    results
  end
  
  def attach_single_image(url, existing_filenames, position, index)
    uri = URI.parse(url)
    filename = File.basename(uri.path)
    content_type = determine_content_type(filename)
    
    # Пропускаем неподдерживаемые форматы
    unless ['image/jpeg', 'image/png'].include?(content_type)
      Rails.logger.warn "📦 Product::ImportImage: Skipping unsupported format: #{filename} (#{content_type})"
      return { success: false, reason: 'unsupported_format' }
    end
    
    # Проверяем дубликаты (thread-safe для Set)
    if existing_filenames.include?(filename)
      Rails.logger.debug "📦 Product::ImportImage: Image already exists: #{filename}"
      return { success: false, reason: 'duplicate' }
    end
    
    # Загружаем изображение
    downloaded_file = URI.open(url, read_timeout: 10)
    
    # Создаем Image
    image = @product.images.build(position: position)
    image.file.attach(
      io: downloaded_file,
      filename: filename,
      content_type: content_type
    )
    
    if image.save
      existing_filenames.add(filename)  # Thread-safe для Set
      Rails.logger.debug "📦 Product::ImportImage: Attached image to product #{@product.id}"
      { success: true }
    else
      Rails.logger.warn "📦 Product::ImportImage: Failed to save image: #{image.errors.full_messages.join(', ')}"
      { success: false, reason: 'validation_failed', errors: image.errors.full_messages }
    end
  rescue => e
    Rails.logger.warn "📦 Product::ImportImage: Failed to attach image #{url}: #{e.message}"
    { success: false, reason: 'error', error: e.message }
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

