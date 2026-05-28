# frozen_string_literal: true

require "test_helper"

module Insales
  module Orders
    class PushFromOrderTest < ActiveSupport::TestCase
      setup do
        @insale = Insale.create!(
          api_link: "shop.insales.ru",
          api_key: "key",
          api_password: "pwd"
        )
        @status = OrderStatus.create!(code: "shipped", title: "Отправлен", position: 1)
        InsalesOrderStatusMapping.create!(
          insale: @insale,
          order_status: @status,
          insales_custom_status_permalink: "shipped",
          insales_financial_status: "paid"
        )
        @order = Order.create!(
          source: "insales",
          insale: @insale,
          insales_order_id: "100",
          order_status: @status
        )
      end

      test "skips non insales orders" do
        order = Order.create!(source: "avito", avito_order_id: "1")

        result = PushFromOrder.call(order: order)

        assert result[:skipped]
        assert_equal "not_insales_order", result[:error]
      end

      test "updates custom status and field values in insales" do
        InsalesOrderStatusMapping.create!(
          insale: @insale,
          order_status: @status,
          insales_custom_status_permalink: "shipped",
          insales_financial_status: "paid"
        )
        InsalesOrderFieldMapping.create!(
          insale: @insale,
          source_key: "order.tracking_number",
          insales_field_id: 174,
          insales_field_handle: "track",
          insales_field_title: "Трек"
        )
        @order.update!(tracking_number: "TRACK-1")

        @insale.stub(:api_init, true) do
          RestClient.stub(:put, true) do
            result = PushFromOrder.call(order: @order)

            assert result[:success]
            assert_includes result[:payload_keys], "custom_status_permalink"
            assert_includes result[:payload_keys], "fields_values_attributes"
          end
        end
      end
    end
  end
end
