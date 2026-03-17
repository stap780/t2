require 'open-uri'

class Product::ImportImage
  MAX_CONCURRENT_DOWNLOADS = 1  # Количество одновременных загрузок
  
  def initialize(product, image_urls)
    @product = product.is_a?(Product) ? product : Product.find(product)
    @image_urls = Array(image_urls)
  end
  
  def call
    return { success: true, attached: 0, reordered: 0 } if @image_urls.empty?
    
    urls_to_process = @image_urls.reject(&:blank?)
    return { success: true, attached: 0, reordered: 0 } if urls_to_process.empty?
    
    # Извлекаем filenames из URL для сопоставления
    url_filenames = {}
    urls_to_process.each do |url|
      begin
        filename = File.basename(URI.parse(url).path)
        url_filenames[url] = filename
      rescue URI::InvalidURIError
        next
      end
    end
    
    # Создаем мапу filename -> Image для существующих изображений
    existing_images_by_filename = @product.images
                                          .joins(file_attachment: :blob)
                                          .includes(file_attachment: :blob)
                                          .index_by { |img| img.file.blob.filename.to_s }
    
    # Создаем мапу URL -> позиция на основе исходного порядка (позиции от 1 до N)
    url_positions = {}
    urls_to_process.each_with_index do |url, index|
      url_positions[url] = index + 1
    end
    
    # Фаза 0: Перемещаем изображения, которых нет в импорте, в конец (чтобы освободить позиции 1..N)
    move_unlisted_images_to_end(existing_images_by_filename, url_filenames.values.to_set, urls_to_process.size)
    
    # Фаза 1: Обновляем позиции существующих изображений согласно порядку в импорте
    reordered_count = update_existing_images_positions(urls_to_process, existing_images_by_filename, url_positions)
    
    # Фаза 2: Добавляем новые изображения с правильными позициями
    existing_filenames = existing_images_by_filename.keys.to_set
    results = download_images_in_batches(urls_to_process, existing_filenames, url_positions)
    attached_count = results.count { |r| r[:success] }
    
    {
      success: true,
      attached: attached_count,
      reordered: reordered_count,
      total: @image_urls.count
    }
  rescue => e
    {
      success: false,
      error: "#{e.class}: #{e.message}",
      attached: 0,
      reordered: 0
    }
  end
  
  private
  
  def move_unlisted_images_to_end(existing_images_by_filename, import_filenames, import_size)
    # Находим изображения, которых нет в импорте
    unlisted_images = existing_images_by_filename.values.reject { |img| import_filenames.include?(img.file.blob.filename.to_s) }
    
    return if unlisted_images.empty?
    
    # Перемещаем их в конец, начиная с позиции после последнего изображения из импорта
    start_position = import_size + 1
    unlisted_images.each_with_index do |image, index|
      new_position = start_position + index
      if image.position != new_position
        image.insert_at(new_position)
        Rails.logger.debug "📦 Product::ImportImage: Moved unlisted image #{image.file.blob.filename} to position #{new_position}"
      end
    end
  rescue => e
    Rails.logger.warn "📦 Product::ImportImage: Error moving unlisted images: #{e.message}"
  end
  
  def update_existing_images_positions(urls, existing_images_by_filename, url_positions)
    reordered_count = 0
    
    # Сначала собираем все изображения, которые нужно переместить
    # и их желаемые позиции, чтобы избежать конфликтов при обновлении
    updates = []
    
    urls.each do |url|
      begin
        filename = File.basename(URI.parse(url).path)
        existing_image = existing_images_by_filename[filename]
        
        next unless existing_image
        
        desired_position = url_positions[url]
        current_position = existing_image.position
        
        # Если позиция не совпадает - добавляем в список для обновления
        if current_position != desired_position
          updates << { image: existing_image, new_position: desired_position, current_position: current_position, filename: filename }
        end
      rescue URI::InvalidURIError => e
        Rails.logger.warn "📦 Product::ImportImage: Invalid URL for position update: #{url}"
        next
      end
    end
    
    # Обновляем позиции (acts_as_list автоматически сдвинет другие изображения)
    # Сортируем по новой позиции, чтобы обновлять в правильном порядке
    updates.sort_by { |u| u[:new_position] }.each do |update|
      begin
        update[:image].insert_at(update[:new_position])
        reordered_count += 1
        Rails.logger.debug "📦 Product::ImportImage: Reordered image #{update[:filename]} from position #{update[:current_position]} to #{update[:new_position]}"
      rescue => e
        Rails.logger.warn "📦 Product::ImportImage: Failed to reorder image #{update[:filename]}: #{e.message}"
      end
    end
    
    reordered_count
  rescue => e
    Rails.logger.warn "📦 Product::ImportImage: Error reordering images: #{e.message}"
    0
  end
  
  def download_images_in_batches(urls, existing_filenames, url_positions)
    results = []
    
    urls.each_slice(MAX_CONCURRENT_DOWNLOADS) do |batch|
      threads = batch.map do |url|
        Thread.new do
          position = url_positions[url]
          attach_single_image(url, existing_filenames, position)
        end
      end
      
      threads.each { |t| results << t.value }
    end
    
    results
  end
  
  def attach_single_image(url, existing_filenames, position)
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

