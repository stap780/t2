# Export job for background processing (inspired by Dizauto ExportJob)
class ExportJob < ApplicationJob
  queue_as :export

  def perform(export)
    Rails.logger.info "🎯 ExportJob: Starting export job for Export ##{export.id} at #{Time.current}"

    success, result = ExportService.new(export).call

    if success
      Rails.logger.info "🎯 ExportJob: Export completed successfully for Export ##{export.id}"
  
      # Broadcast real-time update using Turbo Streams (Rails 8 pattern)
      Turbo::StreamsChannel.broadcast_replace_to(
        "exports",
        target: "export_#{export.id}",
        partial: "exports/export",
        locals: { export: export }
      )
    else
      Rails.logger.error "🎯 ExportJob: Export failed for Export ##{export.id}: #{result}"
    end
    
    [success, result]
  rescue => e
    Rails.logger.error "🎯 ExportJob: Unexpected error for Export ##{export.id}: #{e.message}"
    Rails.logger.error "🎯 ExportJob: #{e.backtrace.join('\n')}"
    
    export.update!(
      status: 'failed',
      error_message: "Job failed: #{e.message}"
    )
    
    raise e
  end
end
