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
        ad_source = build_ad_source_from_mapping
        attrs << ad_source if ad_source
        merge_default_ad_source(attrs)
      end

      private

      def build_from_field_mappings
        ad_source_href = ad_source_attribute&.dig(:href)

        @moysklad.moysklad_order_field_mappings.filter_map do |mapping|
          attribute_meta = attributes_by_href[mapping.ms_attribute_href]
          ms_type = attribute_meta&.dig(:type)
          next if mapping.source_key == "integration.name" && mapping.ms_attribute_href == ad_source_href
          next unless STRING_TYPES.include?(ms_type)

          value = OrderFieldValues.call(order: @order, source_key: mapping.source_key).to_s.presence
          next if value.blank?

          attribute_payload(mapping.ms_attribute_href, value)
        end
      end

      def build_ad_source_from_mapping
        attribute = ad_source_attribute
        return nil unless attribute

        mapping = @moysklad.moysklad_order_field_mappings.find_by(
          ms_attribute_href: attribute[:href],
          source_key: "integration.name"
        )
        return nil unless mapping

        name = OrderFieldValues.call(order: @order, source_key: "integration.name").to_s.presence
        return nil if name.blank?

        entity_href = resolve_ad_source_entity_href(attribute[:custom_entity_meta_href], name)
        return nil if entity_href.blank?

        attribute_payload(attribute[:href], custom_entity_value(entity_href))
      end

      def resolve_ad_source_entity_href(catalog_meta_href, name)
        return nil if catalog_meta_href.blank?

        entities = ad_source_entities_by_catalog[catalog_meta_href]
        entity = entities.find { |row| row[:name].to_s.strip == name.to_s.strip }
        entity&.dig(:href)
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

      def ad_source_entities_by_catalog
        @ad_source_entities_by_catalog ||= Hash.new do |hash, catalog_meta_href|
          hash[catalog_meta_href] = ReferenceData.custom_entity_values(@moysklad, catalog_meta_href)
        end
      end
    end
  end
end
