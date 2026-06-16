# frozen_string_literal: true

module AvitoApi
  module CatalogLinks
    class ProcessItem
      def self.call(avito:, row:, stats:)
        new(avito:, row:, stats:).call
      end

      def initialize(avito:, row:, stats:)
        @avito = avito
        @row = row.stringify_keys
        @stats = stats
      end

      def call
        real_id = extract_real_id
        avito_id = @row["avito_id"].to_s.strip
        if real_id.blank? || avito_id.blank?
          @stats.skipped += 1
          return
        end

        product = AvitoApi::ProductRealId.find_product(real_id)
        unless product
          product = Varbind.find_by(
            bindable: @avito,
            value: avito_id,
            record_type: "Product"
          )&.record

          unless product
            @stats.not_found += 1
            record_not_found_sample(real_id, avito_id)
            return
          end
        end

        unless product.status == "active"
          @stats.skipped += 1
          return
        end

        result = ProductLink.link!(avito: @avito, product: product, avito_id: avito_id, ad_id: real_id)
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

      private

      def extract_real_id
        @row["real_id"].presence || @row["ad_id"].presence
      end

      def record_not_found_sample(real_id, avito_id)
        return if @stats.not_found_samples.size >= CatalogLinks::NOT_FOUND_SAMPLES_LIMIT

        sample = { "avito_id" => avito_id }
        sample["real_id"] = real_id if @row["real_id"].present?
        sample["ad_id"] = real_id if @row["ad_id"].present? && @row["real_id"].blank?
        @stats.not_found_samples << sample
      end
    end
  end
end
