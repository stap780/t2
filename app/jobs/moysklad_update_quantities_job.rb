class MoyskladUpdateQuantitiesJob < ApplicationJob
  queue_as :default

  def perform
    moysklad = Moysklad.first
    unless moysklad
      Rails.logger.error "MoyskladUpdateQuantitiesJob: Moysklad configuration not found"
      return
    end

    service = Moysklad::UpdateQuantitiesService.new(moysklad)
    result = service.call

    if result[:success]
      Rails.logger.info "MoyskladUpdateQuantitiesJob: Successfully updated quantities. Updated: #{result[:updated_count]}, Stations: #{result[:stations_updated]}, With quantity > 0: #{result[:with_quantity_count]}"
    else
      Rails.logger.error "MoyskladUpdateQuantitiesJob: Failed to update quantities: #{result[:error]}"
    end
  rescue StandardError => e
    Rails.logger.error "MoyskladUpdateQuantitiesJob: Error - #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end

