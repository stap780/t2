# Export job for background processing (inspired by Dizauto ExportJob)
class ExportJob < ApplicationJob
  queue_as :export
  # If Export record is missing when job runs, drop it silently
  discard_on ActiveJob::DeserializationError

  # Workaround: Solid Queue worker on macOS (Puma plugin) sometimes doesn't persist finished_at.
  # Explicitly mark job as finished so Mission Control shows it.
  after_perform do |job|
    sq = SolidQueue::Job.find_by(active_job_id: job.job_id)
    sq&.update_column(:finished_at, Time.current)
    Rails.logger.info "🎯 ExportJob: marked finished_at for job #{job.job_id}" if sq
  end

  def perform(export, expected_at = nil)
    # Skip if time changed after enqueue (stale job)
    if expected_at.present? && export.respond_to?(:scheduled_for) && export.scheduled_for.present?
      return unless export.scheduled_for.to_i == expected_at.to_i
    end

    Rails.logger.info "🎯 ExportJob: Starting export job for Export ##{export.id} at #{Time.current}"

    success, result = ExportService.new(export).call

    if success
      Rails.logger.info "🎯 ExportJob: Export completed successfully for Export ##{export.id}"
      # If export has a daily time, schedule the next run
      if export.time.present?
        export.schedule_next_day!
      end
  
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
