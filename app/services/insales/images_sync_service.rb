# frozen_string_literal: true

module Insales
  class ImagesSyncService
    include Insales::EmailNotification

    def initialize(insale = nil)
      @insale = insale || Insale.first
      raise ArgumentError, "Insale configuration not found" unless @insale
    end

    MAX_ERROR_SAMPLES = 20

    def call
      stats = {
        processed: 0,
        images_added: 0,
        skipped: 0,
        not_found: 0,
        errors: 0,
        error_samples: [],
        error_types: Hash.new(0)
      }

      sync_images_single_store(stats)

      result = {
        success: true,
        processed: stats[:processed],
        images_added: stats[:images_added],
        skipped: stats[:skipped],
        not_found: stats[:not_found],
        errors: stats[:errors],
        error_samples: stats[:error_samples],
        error_types: stats[:error_types]
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

    UPLOAD_DELAY_SECONDS = 0.1

    def sync_images_single_store(stats)
      to_upload = []

      # Фаза 1: сбор продуктов без картинок (только GET, без загрузки)
      collect_products_without_images(to_upload, stats)

      # Фаза 2: загрузка изображений с задержкой между продуктами
      upload_collected_products(to_upload, stats)
    rescue StandardError => e
      record_error(stats, e, context: "sync_images_single_store")
      Rails.logger.error "Insales::ImagesSyncService: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    end

    def collect_products_without_images(to_upload, stats)
      batch_size = 250
      page = 1
      max_pages = 400

      loop do
        break if page > max_pages

        creds = Insales::Config::CREDENTIALS[(page - 1) % Insales::Config::CREDENTIALS.size]

        InsalesApi::App.api_key = creds[:api_key]
        InsalesApi::App.configure_api(creds[:api_link], creds[:api_password])

        products = InsalesApi.wait_retry do
          InsalesApi::Product.find(:all, params: { per_page: batch_size, page: page })
        end

        break if products.blank?

        products.each do |ins_product|
          item = collect_product_for_upload(ins_product, stats)
          to_upload << item if item
        end

        sleep 0.1
        page += 1

        break if products.size < batch_size
      end
    end

    def collect_product_for_upload(ins_product, stats)
      stats[:processed] += 1
      ext_product_id = (ins_product.try(:id) || ins_product.try(:[], "id")).to_s.presence

      ins_images = Array(ins_product.try(:images))
      unless ins_images.empty?
        stats[:skipped] += 1
        return nil
      end

      return nil if ext_product_id.blank?

      varbind = Varbind.find_by(bindable: @insale, record_type: "Product", value: ext_product_id)
      unless varbind&.record.is_a?(Product)
        stats[:not_found] += 1
        return nil
      end

      product = varbind.record
      ordered_images = product.images.select { |img| img.file.attached? }
      return nil if ordered_images.empty?

      { ins_product: ins_product, product: product }
    end

    def upload_collected_products(to_upload, stats)
      to_upload.each_with_index do |item, idx|
        creds = Insales::Config::CREDENTIALS[idx % Insales::Config::CREDENTIALS.size]

        InsalesApi::App.api_key = creds[:api_key]
        InsalesApi::App.configure_api(creds[:api_link], creds[:api_password])

        upload_product_images(item[:ins_product], item[:product], stats)

        sleep UPLOAD_DELAY_SECONDS if idx < to_upload.size - 1
      end
    end

    def record_error(stats, error, context: nil)
      stats[:errors] += 1
      stats[:error_types][error.class.name] += 1
      return if stats[:error_samples].size >= MAX_ERROR_SAMPLES

      sample = { "class" => error.class.name, "message" => error.message }
      sample["context"] = context if context.present?
      stats[:error_samples] << sample
    end

    def upload_product_images(ins_product, product, stats)
      ext_product_id = (ins_product.try(:id) || ins_product.try(:[], "id")).to_s.presence

      ordered_images = product.images.select { |img| img.file.attached? }
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
      record_error(stats, e, context: "product #{ext_product_id}")
      Rails.logger.warn "Insales::ImagesSyncService: не удалось добавить изображения для product #{ext_product_id}: #{e.message}"
    end
  end
end
