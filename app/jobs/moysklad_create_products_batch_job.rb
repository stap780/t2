class MoyskladCreateProductsBatchJob < ApplicationJob
  queue_as :default

  def perform
    moysklad = Moysklad.first
    unless moysklad
      Rails.logger.error "MoyskladCreateProductsBatchJob: Moysklad configuration not found"
      return
    end

    service = Moysklad::CreateProductsBatchService.new(moysklad)
    result = service.call

    if result[:success]
      Rails.logger.info "MoyskladCreateProductsBatchJob: Successfully completed batch creation. Created: #{result[:created_count]}, Errors: #{result[:error_count]}, Errors 412: #{result[:error_412_count]}, Total: #{result[:total]}"
    else
      Rails.logger.error "MoyskladCreateProductsBatchJob: Failed to create products: #{result[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "MoyskladCreateProductsBatchJob: Error - #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end

