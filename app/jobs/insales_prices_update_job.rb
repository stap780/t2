# frozen_string_literal: true

class InsalesPricesUpdateJob < ApplicationJob
  queue_as :insales_prices_and_qt_update

  def perform
    result = Insales::PricesUpdateService.new.call

    if result[:success]
      Rails.logger.info "InsalesPricesUpdateJob: Completed. Updated #{result[:updated]} of #{result[:total]} variants"
    else
      Rails.logger.error "InsalesPricesUpdateJob: Failed - #{result[:error]}"
    end

    result
  rescue StandardError => e
    Rails.logger.error "InsalesPricesUpdateJob: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
