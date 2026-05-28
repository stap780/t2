# frozen_string_literal: true

require "test_helper"

module MoyskladApi
  module Orders
    class ApplyFieldMappingsFromMoyskladTest < ActiveSupport::TestCase
      setup do
        @moysklad = Moysklad.create!(api_key: "key", api_password: "secret")
        @moysklad.moysklad_order_field_mappings.create!(
          source_key: "order.tracking_number",
          ms_attribute_href: "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/attributes/track-attr",
          ms_attribute_name: "Трек"
        )
        @order = Order.create!(
          source: "insales",
          insales_order_id: "1",
          number: "15339"
        )
      end

      test "applies string attribute to order field without overwriting channel number" do
        order_json = {
          "attributes" => [
            {
              "meta" => {
                "href" => "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/attributes/track-attr",
                "type" => "string"
              },
              "value" => "TRACK-999"
            }
          ]
        }

        changed = ApplyFieldMappingsFromMoysklad.call(
          order: @order,
          moysklad: @moysklad,
          order_json: order_json
        )

        assert changed
        assert_equal "TRACK-999", @order.reload.tracking_number
        assert_equal "15339", @order.number
      end
    end
  end
end
