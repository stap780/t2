# frozen_string_literal: true
#
# Проверка после запуска экспорта. Запустите в отдельном терминале:
#   ExportJob.perform_later(Export.find(8))
# Затем сразу: rake check_export_job JOB_ID=d592a195-646a-4570-a466-3b943c52cfb8
# Или через 2 мин: rake check_export_job  (проверит последний ExportJob)
#
namespace :check do
  desc "Check ExportJob state. JOB_ID=active_job_id or checks latest"
  task export_job: :environment do
    active_job_id = ENV["JOB_ID"]
    if active_job_id
      j = SolidQueue::Job.find_by(active_job_id: active_job_id)
    else
      j = SolidQueue::Job.where(class_name: "ExportJob").order(created_at: :desc).first
    end

    if j.nil?
      puts "Job NOT FOUND"
      puts "  (deleted from DB after completion?)"
      puts ""
      puts "Last 3 ExportJob:"
      SolidQueue::Job.where(class_name: "ExportJob").order(created_at: :desc).limit(3).each do |x|
        puts "  id=#{x.id} finished=#{x.finished_at} created=#{x.created_at}"
      end
    else
      ce = SolidQueue::ClaimedExecution.exists?(job_id: j.id)
      re = SolidQueue::ReadyExecution.exists?(job_id: j.id)
      status = j.finished_at ? "FINISHED" : (ce ? "IN_PROGRESS" : (re ? "READY" : "?"))
      puts "Job id=#{j.id}:"
      puts "  status: #{status}"
      puts "  finished_at: #{j.finished_at.inspect}"
      puts "  ready=#{re} claimed=#{ce}"
    end

    puts ""
    puts "Finished jobs total: #{SolidQueue::Job.where.not(finished_at: nil).count}"
    puts "Export 8 status: #{Export.find(8).status}"
  end
end
