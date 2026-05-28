# frozen_string_literal: true

module Insales
  class VarbindSyncService
    include Insales::EmailNotification

    def initialize(insale = nil)
      @insale = insale || Insale.first
      raise ArgumentError, "Insale configuration not found" unless @insale
    end

    def call
      stats = {
        processed: 0,
        created: 0,
        skipped: 0,
        not_found: 0,
        errors: 0,
        product_created: 0,
        product_skipped: 0,
        duplicate_barcode: 0,
        error_messages: []
      }

      sync_varbinds_single_store(stats)

      result = {
        success: true,
        processed: stats[:processed],
        created: stats[:created],
        skipped: stats[:skipped],
        not_found: stats[:not_found],
        errors: stats[:errors],
        product_created: stats[:product_created],
        product_skipped: stats[:product_skipped],
        duplicate_barcode: stats[:duplicate_barcode],
        error_messages: stats[:error_messages]
      }

      Rails.logger.info "Insales::VarbindSyncService: Completed. Processed: #{stats[:processed]}, Created: #{stats[:created]}, Errors: #{stats[:errors]}"

      create_email_delivery_and_notify(
        @insale,
        result,
        subject_success: "✅ Синхронизация varbind InSales - успешно",
        subject_errors: "⚠️ Синхронизация varbind InSales - завершено с ошибками",
        mailer_method: "varbind_sync_result"
      )

      result
    rescue StandardError => e
      Rails.logger.error "Insales::VarbindSyncService: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: "#{e.class}: #{e.message}" }
    end

    private

    def sync_varbinds_single_store(stats)
      batch_size = 250
      page = 1
      max_pages = 400

      loop do
        break if page > max_pages

        begin
          creds = Insales::Config::CREDENTIALS[(page - 1) % Insales::Config::CREDENTIALS.size]

          InsalesApi::App.api_key = creds[:api_key]
          InsalesApi::App.configure_api(creds[:api_link], creds[:api_password])

          products = InsalesApi.wait_retry do
            InsalesApi::Product.all(params: { per_page: batch_size, page: page })
          end

          break if products.empty?

          products.each do |ins_product|
            variants = Array(ins_product.try(:variants))
            variants.each do |ins_variant|
              process_insales_variant(ins_product, ins_variant, stats)
            end
          end

          sleep 0.1
        rescue StandardError => e
          stats[:errors] += 1
          stats[:error_messages] << "Страница #{page}: #{e.class} — #{e.message}"
          Rails.logger.error "Insales::VarbindSyncService: page #{page} failed: #{e.class}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
        end

        page += 1
      end
    end

    def process_insales_variant(ins_product, ins_variant, stats)
      stats[:processed] += 1

      barcode = (ins_variant.try(:sku) || ins_variant.try(:[], "sku")).to_s.strip
      ext_variant_id = ins_variant.try(:id).to_s.presence

      return if barcode.blank? || ext_variant_id.blank?

      variants = Variant.where(barcode: barcode)
      if variants.empty?
        stats[:not_found] += 1
        return
      end
      if variants.size > 1
        stats[:duplicate_barcode] += 1
        Rails.logger.warn "VarbindSyncService: пропуск — дубль штрихкода #{barcode} (варианты: #{variants.pluck(:id).join(', ')})"
        return
      end

      variant = variants.first

      existing = Varbind.find_by(bindable: @insale, value: ext_variant_id)
      if existing
        existing.update!(record: variant) if existing.record != variant
        stats[:skipped] += 1
        ensure_product_varbind(ins_product, variant, stats)
        return
      end

      existing_binding = variant.bindings.find_by(bindable: @insale)
      if existing_binding
        existing_binding.update!(value: ext_variant_id) if existing_binding.value != ext_variant_id
        stats[:skipped] += 1
        ensure_product_varbind(ins_product, variant, stats)
        return
      end

      Varbind.create!(record: variant, bindable: @insale, value: ext_variant_id)
      stats[:created] += 1
      ensure_product_varbind(ins_product, variant, stats)
    rescue ActiveRecord::RecordInvalid => e
      stats[:errors] += 1
      stats[:error_messages] << "Variant #{variant&.id || 'N/A'} (barcode #{barcode}): #{e.class} — #{e.message}"
      Rails.logger.warn "Insales::VarbindSyncService: не удалось создать varbind: #{e.message}"
    end

    def ensure_product_varbind(ins_product, variant, stats)
      product = variant.product
      ext_product_id = (ins_product.try(:id) || ins_product.try(:[], "id")).to_s.presence
      return if ext_product_id.blank? || product.blank?

      existing_product_binding = product.bindings.find_by(bindable: @insale)
      if existing_product_binding
        existing_product_binding.update!(value: ext_product_id) if existing_product_binding.value != ext_product_id
        stats[:product_skipped] += 1
        return
      end

      Varbind.create!(record: product, bindable: @insale, value: ext_product_id)
      stats[:product_created] += 1
    rescue ActiveRecord::RecordInvalid => e
      stats[:errors] += 1
      stats[:error_messages] << "Product #{product&.id || 'N/A'} (ext_id #{ext_product_id || 'N/A'}): #{e.class} — #{e.message}"
      Rails.logger.warn "Insales::VarbindSyncService: не удалось создать varbind для Product: #{e.message}"
    end
  end
end
