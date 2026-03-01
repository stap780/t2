# frozen_string_literal: true

module Insales
  class PricesUpdateService
    include Insales::Concerns::EmailNotification

    def initialize(insale = nil)
      @insale = insale || Insale.first
      raise ArgumentError, "Insale configuration not found" unless @insale
    end

    def call
      stats = { total: 0, updated: 0, errors: 0 }
      batch_size = 100

      varbinds = Varbind.where(
        bindable_type: "Insale",
        bindable_id: @insale.id,
        record_type: "Variant"
      ).includes(:record)

      variants_data = varbinds.filter_map do |vb|
        next unless vb.record.is_a?(Variant)

        variant = vb.record
        {
          id: vb.value.to_i,
          price: variant.price.to_f,
          quantity: variant.quantity.to_i
        }
      end

      stats[:total] = variants_data.size

      if variants_data.empty?
        Rails.logger.info "Insales::PricesUpdateService: No variants with varbind for InSales"
        return { success: true, total: 0, updated: 0, errors: 0 }
      end

      variants_data.each_slice(batch_size).with_index do |batch, idx|
        creds = Insales::Config::CREDENTIALS[idx % Insales::Config::CREDENTIALS.size]

        InsalesApi::App.api_key = creds[:api_key]
        InsalesApi::App.configure_api(creds[:api_link], creds[:api_password])

        InsalesApi.wait_retry do
          InsalesApi::Product.variants_group_update(batch)
        end

        stats[:updated] += batch.size
        # sleep 0.1
      end

      result = {
        success: true,
        total: stats[:total],
        updated: stats[:updated],
        errors: stats[:errors]
      }

      Rails.logger.info "Insales::PricesUpdateService: Completed. Updated #{stats[:updated]} of #{stats[:total]} variants"

      create_email_delivery_and_notify(
        @insale,
        result,
        subject_success: "✅ Обновление цен и остатков InSales - успешно",
        subject_errors: "⚠️ Обновление цен и остатков InSales - завершено с ошибками",
        mailer_method: "prices_update_result"
      )

      result
    rescue StandardError => e
      Rails.logger.error "Insales::PricesUpdateService: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: "#{e.class}: #{e.message}" }
    end
  end
end
