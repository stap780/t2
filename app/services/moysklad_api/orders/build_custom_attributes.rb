# frozen_string_literal: true

module MoyskladApi
  module Orders
    class BuildCustomAttributes
      STRING_TYPES = %w[string text].freeze

      def self.call(order:, moysklad:, attribute_metadata: nil)
        new(order:, moysklad:, attribute_metadata:).call
      end

      def initialize(order:, moysklad:, attribute_metadata: nil)
        @order = order
        @moysklad = moysklad
        @attribute_metadata = attribute_metadata
      end

      def call
        attrs = build_from_field_mappings
        merge_default_ad_source(attrs)
      end

      private

      def build_from_field_mappings
        @moysklad.moysklad_order_field_mappings.filter_map do |mapping|
          attribute_meta = attributes_by_href[mapping.ms_attribute_href]
          ms_type = attribute_meta&.dig(:type)
          next unless STRING_TYPES.include?(ms_type)

          value = OrderFieldValues.call(order: @order, source_key: mapping.source_key).to_s.presence
          next if value.blank?

          attribute_payload(mapping.ms_attribute_href, value)
        end
      end

      def merge_default_ad_source(attrs)
        href = @moysklad.default_ad_source_href
        return attrs if href.blank?

        attribute = ad_source_attribute
        return attrs unless attribute

        attribute_href = attribute[:href]
        return attrs if attrs.any? { |row| row.dig("meta", "href") == attribute_href }

        attrs + [attribute_payload(attribute_href, custom_entity_value(href))]
      end

      def ad_source_attribute
        attributes_by_href.values.find do |row|
          row[:type] == "customentity" && row[:name] == Moysklad::AD_SOURCE_ATTRIBUTE_NAME
        end
      end

      def custom_entity_value(href)
        {
          "meta" => {
            "href" => href,
            "type" => "customentity",
            "mediaType" => "application/json"
          }
        }
      end

      def attribute_payload(href, value)
        {
          "meta" => {
            "href" => href,
            "type" => "attributemetadata",
            "mediaType" => "application/json"
          },
          "value" => value
        }
      end

      def attributes_by_href
        @attributes_by_href ||= begin
          rows = @attribute_metadata
          rows = ReferenceData.customerorder_attributes(@moysklad) if rows.nil?
          rows.each_with_object({}) { |row, hash| hash[row[:href]] = row }
        rescue StandardError => e
          Rails.logger.warn "[BuildCustomAttributes] attribute metadata: #{e.message}"
          {}
        end
      end

      def resolve_value(source_key)
        OrderFieldValues.call(order: @order, source_key:)
      end
    end
  end
end
