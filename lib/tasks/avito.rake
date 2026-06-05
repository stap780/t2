# frozen_string_literal: true

require "csv"
require "json"

namespace :avito do
  desc <<~DESC
    Разовая привязка Product ↔ avitoId для not_found из catalog_sync_result.
    ad_id (Новый ID) → CSV → Исходный ID → ProductRealId → ProductLink.

    Аргумент: email_delivery_id (id письма catalog_sync_result).
    CSV по умолчанию: public/Diz4_OldID-NewID.csv

    rake avito:link_not_found_from_mapping[6474]
    DRY_RUN=1 rake avito:link_not_found_from_mapping[6474]
  DESC
  task :link_not_found_from_mapping, [:email_delivery_id] => :environment do |_t, args|
    email_delivery_id = args[:email_delivery_id]
    abort "Укажите email_delivery_id: rake avito:link_not_found_from_mapping[6474]" if email_delivery_id.blank?

    dry_run = ActiveModel::Type::Boolean.new.cast(ENV.fetch("DRY_RUN", "false"))
    only_active = ActiveModel::Type::Boolean.new.cast(ENV.fetch("ONLY_ACTIVE", "true"))
    csv_path = ENV.fetch("CSV_PATH", Rails.root.join("public/Diz4_OldID-NewID.csv").to_s)

    abort "CSV not found: #{csv_path}" unless File.file?(csv_path)

    email_delivery = EmailDelivery.find(email_delivery_id)
    unless email_delivery.mailer_method == "catalog_sync_result"
      abort "EmailDelivery##{email_delivery_id} — не catalog_sync_result (#{email_delivery.mailer_method})"
    end

    samples = Array(email_delivery.operation_details["not_found_samples"])
    abort "EmailDelivery##{email_delivery_id}: not_found_samples пуст" if samples.empty?

    avito = email_delivery.recipient
    unless avito.is_a?(Avito)
      avito_id = email_delivery.metadata&.dig("avito_id")
      avito = avito_id.present? ? Avito.find_by(id: avito_id) : nil
    end
    abort "EmailDelivery##{email_delivery_id}: не удалось определить Avito" unless avito

    mapping = {}
    CSV.foreach(csv_path, headers: true) do |row|
      new_id = row["Новый ID"]&.strip
      source_id = row["Исходный ID (id из фида)"]&.strip
      next if new_id.blank? || source_id.blank?

      mapping[new_id] = source_id
    end

    puts "📄 CSV: #{csv_path} (#{mapping.size} записей)"
    puts "📧 EmailDelivery##{email_delivery_id}"
    puts "🏷️  Avito: #{avito.id} (#{avito.title})"
    puts "📋 Позиций: #{samples.size}"
    puts "🔍 DRY_RUN=#{dry_run}, ONLY_ACTIVE=#{only_active}\n"

    stats = Hash.new(0)
    details = []

    samples.each do |row|
      row = row.stringify_keys
      ad_id = row["ad_id"].to_s.strip
      avito_id_val = row["avito_id"].to_s.strip

      if ad_id.blank? || avito_id_val.blank?
        stats[:skipped] += 1
        next
      end

      source_id = mapping[ad_id]
      unless source_id
        stats[:no_csv_mapping] += 1
        details << { ad_id: ad_id, avito_id: avito_id_val, status: :no_csv_mapping }
        puts "  ⏭  #{ad_id} → нет в CSV"
        next
      end

      product = AvitoApi::ProductRealId.find_product(source_id)
      unless product
        stats[:product_not_found] += 1
        details << {
          ad_id: ad_id, avito_id: avito_id_val, source_id: source_id, status: :product_not_found
        }
        puts "  ❌ #{ad_id} → source #{source_id}: товар не найден"
        next
      end

      if only_active && product.status != "active"
        stats[:not_active] += 1
        details << {
          ad_id: ad_id, avito_id: avito_id_val, source_id: source_id,
          product_id: product.id, status: :not_active
        }
        puts "  ⏸  Product##{product.id}: status=#{product.status}"
        next
      end

      if dry_run
        stats[:linked] += 1
        puts "  ✓  [DRY] #{ad_id} → source #{source_id} → Product##{product.id} → avito_id #{avito_id_val}"
        next
      end

      result = AvitoApi::ProductLink.link!(
        avito: avito,
        product: product,
        avito_id: avito_id_val
      )

      case result.status
      when :linked
        stats[:linked] += 1
        puts "  ✅ Product##{product.id} ← avito_id #{avito_id_val} (ad_id #{ad_id}, source #{source_id})"
      when :existing
        stats[:existing] += 1
        puts "  ↩  Product##{product.id}: привязка уже есть"
      when :conflict
        stats[:conflict] += 1
        puts "  ⚠️  conflict: #{result.error}"
        details << {
          ad_id: ad_id, avito_id: avito_id_val, source_id: source_id,
          status: :conflict, error: result.error
        }
      else
        stats[:error] += 1
        puts "  ❌ #{result.status}: #{result.error}"
        details << {
          ad_id: ad_id, avito_id: avito_id_val, source_id: source_id,
          status: result.status, error: result.error
        }
      end
    end

    puts "\n📊 Итого:"
    stats.each { |key, value| puts "   #{key}: #{value}" }

    if ENV["DETAILS_JSON"].present?
      File.write(ENV["DETAILS_JSON"], JSON.pretty_generate(details))
      puts "📝 Детали: #{ENV['DETAILS_JSON']}"
    end
  end
end
