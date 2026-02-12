# frozen_string_literal: true
#
# Проверка: использует ли приложение правильные базы данных.
# После restore из production важно убедиться, что primary и queue не перепутаны.
#
namespace :db do
  desc "Check which databases the app connects to (primary, queue)"
  task check_connections: :environment do
    puts "=== DATABASE CONNECTIONS ==="
    puts "RAILS_ENV: #{Rails.env}"
    puts ""

    # Primary (products, exports, users...)
    primary_config = ActiveRecord::Base.connection_db_config
    puts "PRIMARY (Export, Product, etc.):"
    puts "  database: #{primary_config.database}"
    puts "  host: #{primary_config.host}"
    puts ""

    # Queue (Solid Queue, Mission Control)
    queue_config = SolidQueue::Job.connection_db_config
    puts "QUEUE (Solid Queue, Mission Control):"
    puts "  database: #{queue_config.database}"
    puts "  host: #{queue_config.host}"
    puts ""

    same_db = primary_config.database == queue_config.database
    if same_db
      puts "⚠️  WARNING: primary and queue use the SAME database!"
      puts "   Solid Queue expects a separate queue database."
      puts "   Check config/database.yml - queue should have database: t2_development_queue"
    else
      puts "✓ primary and queue use different databases (correct)"
    end
    puts ""

    # Quick check: do we have solid_queue tables in queue?
    puts "=== SOLID QUEUE TABLES IN QUEUE DB ==="
    tables = SolidQueue::Job.connection.tables.grep(/solid_queue/)
    puts "  #{tables.join(', ')}"
    puts ""

    # Job count
    puts "=== JOB COUNTS ==="
    puts "  solid_queue_jobs total: #{SolidQueue::Job.count}"
    puts "  finished (finished_at set): #{SolidQueue::Job.where.not(finished_at: nil).count}"
    puts "  ExportJob in queue: #{SolidQueue::Job.where(class_name: 'ExportJob').count}"
  end
end
