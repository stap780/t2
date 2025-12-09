class DetalOszzPriceUpdateJob < ApplicationJob
  queue_as :detal_oszz_price_update

  LOGGER = Logger.new(Rails.root.join("log", "detal_oszz_price_update.log"))

  def perform
    started_at = Time.current
    LOGGER.info "🔄 DetalOszzPriceUpdateJob: Starting OSZZ price update for all Detal records at #{started_at}"

    detals = Detal.where.not(sku: [nil, ''])
    total_count = detals.count
    updated_count = 0
    error_count = 0

    LOGGER.info "🔄 DetalOszzPriceUpdateJob: Found #{total_count} Detal records with SKU"
    
    detals.find_each(batch_size: 100) do |detal|
      begin
        result = detal.get_oszz
        
        if result[:success] == true && result[:price].present?
          detal.update!(oszz_price: result[:price])
          updated_count += 1
          LOGGER.debug "🔄 DetalOszzPriceUpdateJob: Updated Detal ##{detal.id} (SKU: #{detal.sku}) with price: #{result[:price]}"
        else
          LOGGER.debug "🔄 DetalOszzPriceUpdateJob: Skipped Detal ##{detal.id} (SKU: #{detal.sku}) - #{result[:message]}"
        end
      rescue => e
        error_count += 1
        LOGGER.error "🔄 DetalOszzPriceUpdateJob: Error updating Detal ##{detal.id} (SKU: #{detal.sku}): #{e.class} - #{e.message}"
        LOGGER.error e.backtrace.first(5).join("\n")
      end

      # Небольшая задержка между запросами к API, чтобы не перегружать сервер
      sleep(0.1) if detal != detals.last
    end

    finished_at = Time.current
    LOGGER.info "🔄 DetalOszzPriceUpdateJob: Completed at #{finished_at}. Total: #{total_count}, Updated: #{updated_count}, Errors: #{error_count}"
    
    {
      success: true,
      total: total_count,
      updated: updated_count,
      errors: error_count,
      started_at: started_at,
      finished_at: finished_at
    }
  rescue => e
    LOGGER.error "🔄 DetalOszzPriceUpdateJob: Unexpected error: #{e.class} - #{e.message}"
    LOGGER.error e.backtrace.join("\n")
    raise
  end
end
