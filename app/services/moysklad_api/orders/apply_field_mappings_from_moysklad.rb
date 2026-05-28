# frozen_string_literal: true

module MoyskladApi
  module Orders
    # Обратное применение MoyskladOrderFieldMapping: attributes customerorder → поля Order в t2.
    class ApplyFieldMappingsFromMoysklad
      STRING_TYPES = %w[string text].freeze

      def self.call(order:, moysklad:, order_json:)
        new(order:, moysklad:, order_json:).call
      end

      def initialize(order:, moysklad:, order_json:)
        @order = order
        @moysklad = moysklad
        @order_json = order_json
      end

      def call
        rows = Array(@order_json["attributes"])
        return false if rows.empty?

        changed = false
        @moysklad.moysklad_order_field_mappings.find_each do |mapping|
          row = rows.find { |attr| attr.dig("meta", "href") == mapping.ms_attribute_href }
          next unless row

          value = extract_value(row)
          next if value.blank?

          changed = true if apply_value(mapping.source_key, value)
        end

        @order.save! if changed
        changed
      end

      private

      def extract_value(row)
        meta_type = row.dig("meta", "type").to_s
        return row["value"].to_s.presence if STRING_TYPES.include?(meta_type) || row["value"].is_a?(String)

        row.dig("value", "name").to_s.presence
      end

      def apply_value(source_key, value)
        case source_key
        when "order.number"
          return false if @order.insales_channel? || @order.avito_channel?

          @order.number = value
          true
        when "order.avito_marketplace_id"
          @order.avito_marketplace_id = value
          true
        when "order.tracking_number"
          @order.tracking_number = value
          true
        when "order.comment"
          @order.upsert_prefixed_note(value, prefix: "МойСклад: order.comment\n")
          true
        when "order.total_sum"
          @order.total_sum = value.to_f
          true
        when "client.name", "client.email", "client.phone"
          apply_client_field(source_key, value)
        else
          false
        end
      end

      def apply_client_field(source_key, value)
        return false unless @order.client

        attr = source_key.delete_prefix("client.")
        @order.client.public_send("#{attr}=", value)
        @order.client.save!
        true
      end
    end
  end
end
