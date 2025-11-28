class BulkDeleteService
  def initialize(collections, options = {})
    @collections = collections
    @model = options[:model]
    @error_message = []
  end

  def call
    delete_items
    if @error_message.count.positive?
      [false, @error_message]
    else
      [true, t('bulk_delete.success')]
    end
  end

  private

  def delete_items
    @collections.each do |item|
      check_destroy = item.destroy ? true : false
      @error_message << "#{item.id} #{item.errors.full_messages.join(' ')}" if check_destroy == false
    end
  end
end

