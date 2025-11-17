class BulkDeleteJob < ApplicationJob
  queue_as :default

  def perform(collection_ids, options = {})
    model = options[:model]
    items = model.camelize.constantize.where(id: collection_ids)

    result, message = BulkDeleteService.new(items, {model: model}).call
    if result
      Rails.logger.info "Bulk delete successful for #{model}: #{collection_ids.count} items"
    else
      Rails.logger.error "Bulk delete failed for #{model}: #{message}"
    end
  end
end

