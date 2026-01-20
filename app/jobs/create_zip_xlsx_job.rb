class CreateZipXlsxJob < ApplicationJob
  queue_as :default

  def perform(collection_ids, options = {})
    model_name = options[:model] # 'products' or 'detals'
    model_class = model_name.singularize.camelize.constantize # 'Product' or 'Detal'
    items = model_class.where(id: collection_ids)
    download_kind = options[:download_kind]

    success, content = ZipXlsxService.new(items, {model: model_name, download_kind: download_kind}).call
    message = success ? 'Success' : 'Error'
    Turbo::StreamsChannel.broadcast_update_to(
      model_name,
      target: 'bulk_dialog',
      partial: 'shared/pending_bulk',
      layout: false,
      locals: {message: message, content: content}
    )

    if success
      Rails.logger.info "CreateZipXlsxJob: Success for #{model_name}: #{collection_ids.count} items"
    else
      Rails.logger.error "CreateZipXlsxJob: Failed for #{model_name}: #{content.inspect}"
    end
  end
end

