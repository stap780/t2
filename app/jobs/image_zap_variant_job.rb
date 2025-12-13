# Job for generating zap variant with watermark in background
class ImageZapVariantJob < ApplicationJob
  queue_as :image_zap_variants
  
  # Retry при ошибках обработки изображений
  retry_on StandardError, wait: 5.seconds, attempts: 3
  
  # Не повторять если изображение удалено
  discard_on ActiveRecord::RecordNotFound
  
  def perform(image)
    Rails.logger.info "🖼️ ImageZapVariantJob: Starting zap variant generation for Image ##{image.id}"
    
    result = ImageZapVariantService.new(image).call
    
    if result[:success]
      Rails.logger.info "🖼️ ImageZapVariantJob: Successfully generated zap variant for Image ##{image.id}"
    else
      Rails.logger.error "🖼️ ImageZapVariantJob: Failed to generate zap variant for Image ##{image.id}: #{result[:error]}"
    end
    
    result
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "🖼️ ImageZapVariantJob: Image ##{image.id} not found, skipping"
    { success: false, error: "Image not found" }
  rescue => e
    Rails.logger.error "🖼️ ImageZapVariantJob: Unexpected error for Image ##{image.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end

