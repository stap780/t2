# frozen_string_literal: true

module Insales
  class ImagesSyncService
    include Insales::Concerns::EmailNotification

    def initialize(insale = nil, days_back: 3)
      @insale = insale || Insale.first
      @days_back = days_back
      raise ArgumentError, "Insale configuration not found" unless @insale
    end

    def call
      stats = { processed: 0, images_added: 0, skipped: 0, not_found: 0, errors: 0 }

      sync_images_single_store(stats)

      result = {
        success: true,
        processed: stats[:processed],
        images_added: stats[:images_added],
        skipped: stats[:skipped],
        not_found: stats[:not_found],
        errors: stats[:errors]
      }

      Rails.logger.info "Insales::ImagesSyncService: Completed. Processed: #{stats[:processed]}, Images added: #{stats[:images_added]}, Errors: #{stats[:errors]}"

      create_email_delivery_and_notify(
        @insale,
        result,
        subject_success: "✅ Синхронизация изображений InSales - успешно",
        subject_errors: "⚠️ Синхронизация изображений InSales - завершено с ошибками",
        mailer_method: "images_sync_result"
      )

      result
    rescue StandardError => e
      Rails.logger.error "Insales::ImagesSyncService: #{e.class}: #{e.message}"
      Rails.logger.error e.backtrace.first(10).join("\n")
      { success: false, error: "#{e.class}: #{e.message}" }
    end

    private

    def sync_images_single_store(stats)
      batch_size = 250
      page = 1
      max_pages = 100
      since_str = @days_back.days.ago.strftime("%Y-%m-%dT%H:%M:%S%:z")

      loop do
        break if page > max_pages

        creds = Insales::Config::CREDENTIALS[(page - 1) % Insales::Config::CREDENTIALS.size]

        InsalesApi::App.api_key = creds[:api_key]
        InsalesApi::App.configure_api(creds[:api_link], creds[:api_password])

        products = InsalesApi.wait_retry do
          InsalesApi::Product.find(:all, params: {
            per_page: batch_size,
            page: page,
            updated_since: since_str
          })
        end

        break if products.blank?

        products.each { |ins_product| process_insales_product_images(ins_product, stats) }

        sleep 0.1
        page += 1

        break if products.size < batch_size
      end
    rescue StandardError => e
      stats[:errors] += 1
      Rails.logger.error "Insales::ImagesSyncService: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    end

    def process_insales_product_images(ins_product, stats)
      stats[:processed] += 1
      ext_product_id = (ins_product.try(:id) || ins_product.try(:[], "id")).to_s.presence

      ins_images = Array(ins_product.try(:images))
      unless ins_images.empty?
        stats[:skipped] += 1
        return
      end

      return if ext_product_id.blank?

      varbind = Varbind.find_by(bindable: @insale, record_type: "Product", value: ext_product_id)
      unless varbind&.record.is_a?(Product)
        stats[:not_found] += 1
        return
      end

      product = varbind.record
      ordered_images = product.images.order(:position).select { |img| img.file.attached? }
      return if ordered_images.empty?

      ins_image_ids = []
      ordered_images.each do |img|
        im = InsalesApi::Image.new(
          attachment: Base64.encode64(img.file.download),
          filename: img.file.filename.to_s,
          title: img.file.filename.to_s,
          product_id: ext_product_id.to_i
        )
        im.save
        ins_image_ids << im.id
      end

      ins_variant = Array(ins_product.try(:variants)).first
      if ins_variant && ins_image_ids.any?
        ins_variant.image_ids = ins_image_ids
        ins_variant.save
      end

      stats[:images_added] += ins_image_ids.size
    rescue StandardError => e
      stats[:errors] += 1
      Rails.logger.warn "Insales::ImagesSyncService: не удалось добавить изображения для product #{ext_product_id}: #{e.message}"
    end
  end
end
