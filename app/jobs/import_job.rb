class ImportJob < ApplicationJob
  queue_as :default
  
  def perform(import)
    Rails.logger.info "🚀 ImportJob STARTED for Import ##{import.id} (#{import.name})"

    begin
      result = ImportService.new(import).call

      if result[:success]
        Rails.logger.info "✅ ImportJob COMPLETED successfully for Import ##{import.id}: #{result[:message]}"
      else
        Rails.logger.error "❌ ImportJob FAILED for Import ##{import.id}: #{result[:message]}"
      end
    rescue => e
      Rails.logger.error "💥 ImportJob CRASHED for Import ##{import.id}: #{e.message}"
      Rails.logger.error "💥 ImportJob BACKTRACE: #{e.backtrace.join('\n')}"

      # Update import with job-level error if service didn't handle it
      import.update!(
        status: 'failed',
        error_message: "Job error: #{e.class.name}: #{e.message}"
      ) unless import.failed?

      raise # Re-raise so Solid Queue can track the failure
    end

    Rails.logger.info "🏁 ImportJob FINISHED for Import ##{import.id}"
  end
end
