# frozen_string_literal: true
#
# Solid Queue diagnostics. Job 78 (ExportJob) was in scheduled_executions for 22:00,
# not orphaned - it will appear in Mission Control under "Scheduled" tab.
# Immediate runs (e.g. job 74) go: ready -> claimed -> finished.
#

namespace :solid_queue do
  desc "Check job state and claimed/ready. Usage: JOB_ID=78 rake solid_queue:check_job_78"
  task check_job_78: :environment do
    job_id = ENV["JOB_ID"] || 78

    j = SolidQueue::Job.find_by(id: job_id)
    if j.nil?
      puts "Job ##{job_id} not found"
      exit 1
    end

    puts "=== Job ##{job_id} ==="
    puts "  queue: #{j.queue_name}"
    puts "  class_name: #{j.class_name}"
    puts "  created_at: #{j.created_at}"
    puts "  finished_at: #{j.finished_at.inspect}"

    ce = SolidQueue::ClaimedExecution.find_by(job_id: job_id)
    puts "  In claimed_executions: #{ce ? "YES (stuck!)" : "no"}"

    re = SolidQueue::ReadyExecution.find_by(job_id: job_id)
    puts "  In ready_executions: #{re ? "YES (waiting)" : "no"}"

    se = SolidQueue::ScheduledExecution.find_by(job_id: job_id)
    puts "  In scheduled_executions: #{se ? "YES (scheduled_at=#{se.scheduled_at})" : "no"}"

    puts ""
    puts "=== Claimed jobs (possibly stuck) ==="
    SolidQueue::ClaimedExecution.includes(:job).limit(10).each do |c|
      puts "  job_id=#{c.job_id} #{c.job&.class_name} created=#{c.created_at}"
    end

    puts ""
    puts "=== Recent ExportJobs with nil finished_at ==="
    SolidQueue::Job.where(class_name: "ExportJob", finished_at: nil).order(created_at: :desc).limit(5).each do |j|
      puts "  id=#{j.id} created_at=#{j.created_at}"
    end
  end

  desc "Fix orphaned jobs: mark as finished (if export completed) or re-queue. JOB_IDS=78,79 or CLASS=ExportJob. ACTION=mark_finished|requeue. DRY_RUN=1 to preview."
  task fix_orphaned: :environment do
    dry_run = ENV["DRY_RUN"] == "1"
    action = ENV["ACTION"] || "mark_finished"
    job_ids = ENV["JOB_IDS"]&.split(",")&.map(&:strip)&.map(&:to_i)
    class_filter = ENV["CLASS"]

    scope = SolidQueue::Job.where(finished_at: nil)
    scope = scope.where(id: job_ids) if job_ids.present?
    scope = scope.where(class_name: class_filter) if class_filter.present?

    orphaned = scope.select do |j|
      !SolidQueue::ReadyExecution.exists?(job_id: j.id) &&
        !SolidQueue::ClaimedExecution.exists?(job_id: j.id) &&
        !SolidQueue::ScheduledExecution.exists?(job_id: j.id)
    end

    if orphaned.empty?
      puts "No orphaned jobs found."
      next
    end

    puts "Found #{orphaned.size} orphaned job(s):"
    orphaned.each { |j| puts "  id=#{j.id} #{j.class_name} queue=#{j.queue_name} created=#{j.created_at}" }

    if dry_run
      puts ""
      puts "DRY_RUN: Would #{action} these. Run without DRY_RUN=1 to apply."
      next
    end

    orphaned.each do |job|
      case action
      when "mark_finished"
        job.update_column(:finished_at, Time.current)
        puts "Marked job ##{job.id} as finished (will appear in Mission Control Finished)"
      when "requeue"
        SolidQueue::ReadyExecution.create!(job_id: job.id, queue_name: job.queue_name, priority: job.priority || 0)
        puts "Re-queued job ##{job.id} - will run again!"
      else
        puts "Unknown ACTION=#{action}. Use mark_finished or requeue."
      end
    end
  end
end
