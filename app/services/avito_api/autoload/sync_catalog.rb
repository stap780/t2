# frozen_string_literal: true

module AvitoApi
  module Autoload
    # Синхронизация Varbind Product ↔ avitoId из отчёта автозагрузки.
    # GET /autoload/v2/reports → GET /autoload/v2/reports/{report_id}/items
    class SyncCatalog
      Stats = CatalogLinks::Stats
      PER_PAGE = 200

      def self.call(avito:)
        new(avito:).call
      end

      def initialize(avito:)
        @avito = avito
        @client = Client.new(avito:)
        @stats = Stats.empty
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
          items.each { |row| CatalogLinks::ProcessItem.call(avito: @avito, row: row, stats: @stats) }

          pages = body.dig("meta", "pages").to_i
          page += 1
          break if items.empty? || page >= pages

          sleep(1)
        end
      end
    end
  end
end
