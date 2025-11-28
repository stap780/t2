class ProductImageJob < ApplicationJob
  queue_as :product_images
  
  # Retry при сетевых ошибках
  retry_on OpenURI::HTTPError, wait: 10.seconds, attempts: 3
  retry_on Timeout::Error, wait: 10.seconds, attempts: 3
  
  # Не повторять при ошибках валидации
  discard_on ActiveRecord::RecordInvalid
  
  def perform(product_id, image_urls)
    Rails.logger.info "📦 ProductImageJob: Starting image import for Product ##{product_id}"
    
    product = Product.find(product_id)
    result = Product::ImportImage.new(product, image_urls).call
    
    if result[:success]
      Rails.logger.info "📦 ProductImageJob: Attached #{result[:attached]}/#{result[:total]} images to Product ##{product_id}"
    else
      Rails.logger.error "📦 ProductImageJob: Failed for Product ##{product_id}: #{result[:error]}"
    end
    
    result
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.warn "📦 ProductImageJob: Product ##{product_id} not found, skipping"
    { success: false, error: "Product not found" }
  rescue => e
    Rails.logger.error "📦 ProductImageJob: Unexpected error for Product ##{product_id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end

