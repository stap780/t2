# frozen_string_literal: true

require "test_helper"

module Insales
  module Orders
    class BuildFieldValuesTest < ActiveSupport::TestCase
      setup do
        @insale = Insale.create!(
          api_link: "shop.insales.ru",
          api_key: "key",
          api_password: "pwd"
        )
        InsalesOrderFieldMapping.create!(
          insale: @insale,
          source_key: "order.tracking_number",
          insales_field_id: 10,
          insales_field_handle: "track"
        )
        @order = Order.create!(
          source: "insales",
          insale: @insale,
          insales_order_id: "100",
          tracking_number: "TRACK-42"
        )
      end

      test "builds fields_values_attributes from mappings" do
        rows = BuildFieldValues.call(order: @order)

        assert_equal 1, rows.size
        assert_equal "TRACK-42", rows.first["value"]
        assert_equal 10, rows.first["field_id"]
        assert_equal "track", rows.first["handle"]
      end
    end
  end
end
