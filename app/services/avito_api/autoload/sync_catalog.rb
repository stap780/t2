# frozen_string_literal: true

module AvitoApi
  module Autoload
    # Синхронизация Varbind Product ↔ avitoId из отчёта автозагрузки.
    # GET /autoload/v2/reports → GET /autoload/v2/reports/{report_id}/items
    class SyncCatalog
      Stats = Struct.new(
        :linked, :existing, :not_found, :skipped, :conflicts, :errors, :not_found_samples,
        keyword_init: true
      )
      PER_PAGE = 200
      NOT_FOUND_SAMPLES_LIMIT = 500

      def self.call(avito:)
        new(avito:).call
      end

      def initialize(avito:)
        @avito = avito
        @client = Client.new(avito:)
        @stats = Stats.new(
          linked: 0, existing: 0, not_found: 0, skipped: 0, conflicts: 0,
          errors: [], not_found_samples: []
        )
      end

      def call
        if AvitoApi::Auth.access_token(@avito).blank?
          @stats.errors << "no_avito_token"
          return @stats
        end

        report_id = latest_success_report_id
        if report_id.blank?
          @stats.errors << "no_autoload_report"
          return @stats
        end

        sync_report(report_id)
        @stats
      end

      private

      def latest_success_report_id
        body = @client.get("/autoload/v2/reports")
        reports = body&.fetch("reports", []) || []
        report = reports.find do |row|
          row["finished_at"].present? && row["status"].to_s.match?(/success/)
        end
        report&.dig("id")
      end

      def sync_report(report_id)
        page = 0

        loop do
          body = @client.get(
            "/autoload/v2/reports/#{report_id}/items",
            params: { page: page, per_page: PER_PAGE }
          )
          break if body.blank?

          items = body["items"] || []
          items.each { |row| process_item(row) }

          pages = body.dig("meta", "pages").to_i
          page += 1
          break if items.empty? || page >= pages

          sleep(1)
        end
      end

      def process_item(row)
        ad_id = row["ad_id"].to_s.strip
        avito_id = row["avito_id"].to_s.strip
        if ad_id.blank? || avito_id.blank?
          @stats.skipped += 1
          return
        end

        product = AvitoApi::ProductRealId.find_product(ad_id)
        unless product
          product = Varbind.find_by(
            bindable: @avito,
            value: avito_id,
            record_type: "Product"
          )&.record

          unless product
            @stats.not_found += 1
            record_not_found_sample(ad_id, avito_id)
            return
          end
        end

        unless product.status == "active"
          @stats.skipped += 1
          return
        end

        result = ProductLink.link!(avito: @avito, product: product, avito_id: avito_id, ad_id: ad_id)
        case result.status
        when :linked
          @stats.linked += 1
        when :existing
          @stats.existing += 1
        when :conflict
          @stats.conflicts += 1
          @stats.errors << result.error if result.error.present?
        else
          @stats.skipped += 1
          @stats.errors << result.error if result.error.present?
        end
      end

      def record_not_found_sample(ad_id, avito_id)
        return if @stats.not_found_samples.size >= NOT_FOUND_SAMPLES_LIMIT

        @stats.not_found_samples << { "ad_id" => ad_id, "avito_id" => avito_id }
      end
    end
  end
end
