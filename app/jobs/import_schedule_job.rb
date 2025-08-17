class ImportScheduleJob < ApplicationJob
  queue_as :default
  # If the ImportSchedule record was deleted before the job runs,
  # Active Job will raise ActiveJob::DeserializationError. Discard it.
  discard_on ActiveJob::DeserializationError

  def perform(import_schedule, expected_at = nil)
    # Skip if schedule was set inactive after enqueue
    return unless import_schedule&.active?
    # If the schedule's planned time changed after enqueue, skip this stale job
    if expected_at.present? && import_schedule.scheduled_for.present?
      return unless import_schedule.scheduled_for.to_i == expected_at.to_i
    end
    # Create a new Import for the schedule's user each time it fires
    import = import_schedule.user.imports.create!(
      name: import_schedule.name.presence || "Scheduled Import #{Time.current.strftime('%Y%m%d_%H%M')}",
      status: 'pending'
    )

    # Kick off the actual import processing
    ImportJob.perform_later(import)

  # Enqueue the next occurrence if still active
  import_schedule.enqueue_next_run!(from_time: Time.zone.now)
  end
end
