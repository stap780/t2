# Service for generating zap variant with watermark using Vips
class ImageZapVariantService
  require 'image_processing/vips'

  WATERMARK_PATH = Rails.root.join('public', 'zap1_watermark50.png')
  ZAP_WIDTH = 1152
  ZAP_HEIGHT = 864
  ZAP_QUALITY = 75

  def initialize(image)
    @image = image
  end

  def call
    return { success: false, error: 'Image file not attached' } unless @image.file.attached?
    return { success: false, error: 'Watermark file not found' } unless watermark_exists?

    Rails.logger.info "🖼️ ImageZapVariantService: Generating zap variant for Image ##{@image.id}"

    begin
      # Скачиваем оригинальное изображение
      original_file = @image.file.download
      temp_original = Tempfile.new(['original', File.extname(@image.file.filename.to_s)])
      temp_original.binmode
      temp_original.write(original_file)
      temp_original.rewind

      # Генерируем zap вариант с водяным знаком
      processed_file = generate_zap_variant(temp_original.path)

      # Сохраняем как вариант через Active Storage
      # Используем кастомный ключ для zap варианта
      zap_blob = ActiveStorage::Blob.create_and_upload!(
        io: File.open(processed_file.path),
        filename: "zap_#{@image.file.filename}",
        content_type: @image.file.content_type
      )

      # Связываем zap blob с оригинальным blob через метаданные
      # Сохраняем связь в метаданных оригинального blob
      @image.file.blob.update(metadata: @image.file.blob.metadata.merge(
        zap_variant_key: zap_blob.key
      ))

      temp_original.close
      temp_original.unlink
      processed_file.close
      processed_file.unlink

      Rails.logger.info "🖼️ ImageZapVariantService: Successfully generated zap variant for Image ##{@image.id}"
      { success: true, blob: zap_blob }
    rescue => e
      Rails.logger.error "🖼️ ImageZapVariantService: Error generating zap variant for Image ##{@image.id}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: e.message }
    end
  end

  private

  def watermark_exists?
    File.exist?(WATERMARK_PATH)
  end

  def generate_zap_variant(original_path)
    require 'vips'
    
    # Генерируем zap вариант: resize + водяной знак
    temp_result = Tempfile.new(['zap', '.jpg'])
    
    # Загружаем оригинальное изображение и resize до 1152x864
    image = Vips::Image.new_from_file(original_path)
    scale = [ZAP_WIDTH.to_f / image.width, ZAP_HEIGHT.to_f / image.height].min
    resized = image.resize(scale)
    
    # Загружаем водяной знак
    watermark = Vips::Image.new_from_file(WATERMARK_PATH.to_s)
    
    # Вычисляем позицию для southwest (нижний левый угол)
    watermark_x = 0
    watermark_y = resized.height - watermark.height
    
    # Накладываем водяной знак через composite2
    # Используем :over для наложения с прозрачностью
    result_image = resized.composite2(watermark, :over, x: watermark_x, y: watermark_y)
    
    # Сохраняем результат
    result_image.write_to_file(temp_result.path, Q: ZAP_QUALITY, strip: true)
    
    temp_result
  end

  def watermark_path
    WATERMARK_PATH.to_s
  end
end

