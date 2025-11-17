class CreateZipXlsxJob < ApplicationJob
  queue_as :default

  def perform(collection_ids, options = {})
    model = options[:model]
    items = model.camelize.constantize.where(id: collection_ids)

    success, content = ZipXlsxService.new(items, {model: model}).call
    message = success ? 'Success' : 'Error'
    Turbo::StreamsChannel.broadcast_update_to(
      'products',
      target: 'bulk_dialog',
      partial: 'shared/pending_bulk',
      layout: false,
      locals: {message: message, content: content}
    )

    if success
      Rails.logger.info "CreateZipXlsxJob: Success for #{model}: #{collection_ids.count} items"
    else
      Rails.logger.error "CreateZipXlsxJob: Failed for #{model}: #{content.inspect}"
    end
  end
end

