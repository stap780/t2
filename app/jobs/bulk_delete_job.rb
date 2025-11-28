class BulkDeleteJob < ApplicationJob
  queue_as :default

  def perform(collection_ids, options = {})
    model_name = options[:model] # 'products' or 'detals'
    model_class = model_name.singularize.camelize.constantize # 'Product' or 'Detal'
    items = model_class.where(id: collection_ids)

    result, message = BulkDeleteService.new(items, {model: model_class}).call
    flash = ActionDispatch::Flash::FlashHash.new
    flash[:notice] = message
    Turbo::StreamsChannel.broadcast_update_to(
      model_name,
      target: 'flash',
      partial: 'shared/flash',
      layout: false,
      locals: {flash: flash}
    )
    if result
      Rails.logger.info "Bulk delete successful for #{model_class}: #{collection_ids.count} items"
    else
      Rails.logger.error "Bulk delete failed for #{model_class}: #{message}"
    end
  end
end