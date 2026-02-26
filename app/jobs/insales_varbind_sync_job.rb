# frozen_string_literal: true

class InsalesVarbindSyncJob < ApplicationJob
  queue_as :insales_varbind_sync

  def perform
    result = Insales::VarbindSyncService.new.call

    if result[:success]
      Rails.logger.info "InsalesVarbindSyncJob: Completed. Processed: #{result[:processed]}, Created: #{result[:created]}, Errors: #{result[:errors]}"
    else
      Rails.logger.error "InsalesVarbindSyncJob: Failed - #{result[:error]}"
    end

    result
  rescue StandardError => e
    Rails.logger.error "InsalesVarbindSyncJob: #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end
