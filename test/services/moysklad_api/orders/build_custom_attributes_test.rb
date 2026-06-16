# frozen_string_literal: true

require "test_helper"

module MoyskladApi
  module Orders
    class BuildCustomAttributesTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      def attribute_metadata(*rows)
        rows.map do |row|
          href, type = row[0], row[1]
          extra = row[2..]&.grep(Hash)&.reduce({}, :merge) || {}
          { href:, name: href, type:, required: false, custom_entity_meta_href: nil, **extra }
        end
      end

      test "builds string attributes from field mappings" do
        moysklad = Moysklad.create!(api_key: "k", api_password: "p")
        href = "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/attributes/1"
        moysklad.moysklad_order_field_mappings.create!(
          source_key: "order.number",
          ms_attribute_href: href,
          ms_attribute_name: "Номер"
        )
        order = Order.new(source: "avito", number: "A-1")

        attrs = BuildCustomAttributes.call(
          order: order,
          moysklad: moysklad,
          attribute_metadata: attribute_metadata([href, "string"])
        )

        assert_equal 1, attrs.size
        assert_equal "A-1", attrs.first["value"]
      end

      test "merges default ad source when configured on moysklad" do
        moysklad = Moysklad.create!(
          api_key: "k",
          api_password: "p",
          default_ad_source_href: "https://api.moysklad.ru/api/remap/1.2/entity/customentity/cat/entity-1",
          default_ad_source_name: "Dizauto.ru"
        )
        attr_href = "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/attributes/ad"
        order = Order.new(source: "insales", number: "1")

        attrs = BuildCustomAttributes.call(
          order: order,
          moysklad: moysklad,
          attribute_metadata: attribute_metadata(
            [attr_href, "customentity", name: Moysklad::AD_SOURCE_ATTRIBUTE_NAME]
          )
        )

        assert_equal 1, attrs.size
        assert_equal attr_href, attrs.first.dig("meta", "href")
        assert_equal moysklad.default_ad_source_href, attrs.first.dig("value", "meta", "href")
      end

      test "uses integration name mapping for ad source when entity matches" do
        moysklad = Moysklad.create!(api_key: "k", api_password: "p", title: "МойСклад")
        avito = Avito.create!(title: "Dizauto Avito", api_id: "id-#{SecureRandom.hex(4)}", api_secret: "sec")
        ad_attr_href = "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/attributes/ad"
        catalog_href = "https://api.moysklad.ru/api/remap/1.2/entity/customentity/cat/ad-sources"
        entity_href = "https://api.moysklad.ru/api/remap/1.2/entity/customentity/cat/ad-sources/entity-avito"
        moysklad.moysklad_order_field_mappings.create!(
          source_key: "integration.name",
          ms_attribute_href: ad_attr_href,
          ms_attribute_name: Moysklad::AD_SOURCE_ATTRIBUTE_NAME
        )
        order = Order.new(source: "avito", avito: avito)

        with_singleton_stub(
          ReferenceData,
          :custom_entity_values,
          ->(*) { [{ href: entity_href, name: "Dizauto Avito" }] }
        ) do
          attrs = BuildCustomAttributes.call(
            order: order,
            moysklad: moysklad,
            attribute_metadata: attribute_metadata(
              [ad_attr_href, "customentity", name: Moysklad::AD_SOURCE_ATTRIBUTE_NAME, custom_entity_meta_href: catalog_href]
            )
          )

          assert_equal 1, attrs.size
          assert_equal entity_href, attrs.first.dig("value", "meta", "href")
        end
      end

      test "falls back to default ad source when integration mapping missing" do
        moysklad = Moysklad.create!(
          api_key: "k",
          api_password: "p",
          title: "МойСклад",
          default_ad_source_href: "https://api.moysklad.ru/api/remap/1.2/entity/customentity/cat/entity-default"
        )
        ad_attr_href = "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/attributes/ad"
        avito = Avito.create!(title: "Dizauto Avito", api_id: "id-#{SecureRandom.hex(4)}", api_secret: "sec")
        order = Order.new(source: "avito", avito: avito)

        attrs = BuildCustomAttributes.call(
          order: order,
          moysklad: moysklad,
          attribute_metadata: attribute_metadata(
            [ad_attr_href, "customentity", name: Moysklad::AD_SOURCE_ATTRIBUTE_NAME]
          )
        )

        assert_equal moysklad.default_ad_source_href, attrs.first.dig("value", "meta", "href")
      end

      test "maps avito marketplace id and tracking number" do
        moysklad = Moysklad.create!(api_key: "k", api_password: "p")
        avito_href = "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/attributes/avito"
        track_href = "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/attributes/track"
        moysklad.moysklad_order_field_mappings.create!(
          source_key: "order.avito_marketplace_id",
          ms_attribute_href: avito_href,
          ms_attribute_name: "Авито заказ №"
        )
        moysklad.moysklad_order_field_mappings.create!(
          source_key: "order.tracking_number",
          ms_attribute_href: track_href,
          ms_attribute_name: "Трек"
        )
        order = Order.new(
          source: "avito",
          avito_marketplace_id: "70000000429007323",
          tracking_number: "TRACK-999"
        )

        attrs = BuildCustomAttributes.call(
          order: order,
          moysklad: moysklad,
          attribute_metadata: attribute_metadata([avito_href, "string"], [track_href, "string"])
        )

        assert_equal 2, attrs.size
        values = attrs.map { |a| a["value"] }
        assert_includes values, "70000000429007323"
        assert_includes values, "TRACK-999"
      end
    end
  end
end
