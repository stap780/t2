class ImportSchedule < ApplicationRecord
  belongs_to :user

  RECURRENCES = %w[daily].freeze # Can be extended to weekdays/custom later

  validates :time, presence: true
  validates :recurrence, inclusion: { in: RECURRENCES }

  after_commit :enqueue_on_create, on: :create
  after_update :handle_enqueue_on_update
  before_destroy :cancel_pending_job

  # Compute the next run at given time-of-day in app timezone
  def next_run_at(from_time: Time.zone.now)
    return nil if time.blank?
    h, m = time.split(":").map(&:to_i)
    candidate = from_time.in_time_zone.change(hour: h, min: m, sec: 0)
    candidate += 1.day if candidate <= from_time
    candidate
  end

  def enqueue_run!
    return unless active
    ts = next_run_at
    return unless ts
    update_columns(scheduled_for: ts)
    job = ImportScheduleJob.set(wait_until: ts).perform_later(self, ts)
    update_columns(active_job_id: job.job_id)
  end

  def enqueue_next_run!(from_time: Time.zone.now)
    return unless active
    ts = next_run_at(from_time: from_time + 1.minute)
    return unless ts
    update_columns(scheduled_for: ts)
    job = ImportScheduleJob.set(wait_until: ts).perform_later(self, ts)
    update_columns(active_job_id: job.job_id)
  end

  private

  # Enqueue initial job after creation when active and time present
  def enqueue_on_create
    enqueue_run! if active && time.present?
  end

  # On updates, only react to meaningful changes
  def handle_enqueue_on_update
    if saved_change_to_time?
      # Time changed (including to blank): replace or cancel
      cancel_pending_job
      enqueue_run! if active && time.present?
    elsif saved_change_to_active?
      # Active toggled: enqueue only when activated and time exists; cancel when deactivated
      if active && time.present?
        enqueue_run!
      else
        cancel_pending_job
      end
    end
  end

  # Remove pending scheduled job if present
  def cancel_pending_job
    return if active_job_id.blank?
    # Delete the Solid Queue job row(s) matching this active_job_id
    if defined?(SolidQueue::Job)
      SolidQueue::Job.where(active_job_id: active_job_id, finished_at: nil).delete_all
    end
    if defined?(SolidQueue::ScheduledExecution)
      SolidQueue::ScheduledExecution.joins(:job).where(solid_queue_jobs: { active_job_id: active_job_id }).delete_all
    end
    update_columns(active_job_id: nil)
  rescue => e
    Rails.logger.warn("ImportSchedule##{id}: failed to cancel pending job #{active_job_id}: #{e.message}")
  end
end
