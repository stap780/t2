class MoyskladSyncProductJob < ApplicationJob
  queue_as :moysklad_sync_product

  def perform(product_id, moysklad_id = nil)
    product = Product.find(product_id)
    moysklad = moysklad_id ? Moysklad.find(moysklad_id) : Moysklad.first
    
    unless moysklad
      Rails.logger.error "MoyskladSyncProductJob: Moysklad configuration not found for product #{product_id}"
      return
    end

    service = Moysklad::SyncProductService.new(product, moysklad)
    result = service.call
    
    if result[:success]
      Rails.logger.info "MoyskladSyncProductJob: Successfully synced product ##{product_id} with Moysklad"
    else
      Rails.logger.warn "MoyskladSyncProductJob: Failed to sync product ##{product_id}: #{result[:error]}"
    end
    
    result
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "MoyskladSyncProductJob: Product #{product_id} not found: #{e.message}"
    raise
  rescue StandardError => e
    Rails.logger.error "MoyskladSyncProductJob: Error for product #{product_id}: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end

