# frozen_string_literal: true

class InsalesImagesSyncJob < ApplicationJob
  queue_as :insales_images_sync

  def perform(days_back: 3)
    result = Insales::ImagesSyncService.new(days_back: days_back).call

    if result[:success]
      Rails.logger.info "InsalesImagesSyncJob: Completed. Processed: #{result[:processed]}, Images added: #{result[:images_added]}, Errors: #{result[:errors]}"
    else
      Rails.logger.error "InsalesImagesSyncJob: Failed - #{result[:error]}"
    end

    result
  rescue StandardError => e
    Rails.logger.error "InsalesImagesSyncJob: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
