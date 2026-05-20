# frozen_string_literal: true

require "test_helper"

module Insales
  module Orders
    class ImportTest < ActiveSupport::TestCase
      setup do
        @insale = Insale.create!(
          api_link: "test-shop.insales.ru",
          api_key: "key-#{SecureRandom.hex(4)}",
          api_password: "pwd-#{SecureRandom.hex(4)}"
        )
        @variant = Variant.create!(sku: "SKU-INS-1")
        Varbind.create!(
          bindable: @insale,
          record: @variant,
          value: "42"
        )
        @status = OrderStatus.find_or_create_by!(code: "new") do |s|
          s.title = "Новый"
          s.position = 1
        end
        InsalesOrderStatusMapping.create!(
          order_status: @status,
          insales_status_key: "new",
          insales_status_title: "Новый"
        )
      end

      test "imports order with order lines and status mapping" do
        payload = {
          "id" => 1001,
          "number" => 5001,
          "total_price" => 1500.0,
          "currency_code" => "RUR",
          "custom_status" => { "permalink" => "new", "title" => "Новый" },
          "client" => {
            "id" => 7,
            "email" => "buyer@example.com",
            "name" => "Иван",
            "phone" => "+79001234567"
          },
          "order_lines" => [
            {
              "variant_id" => 42,
              "quantity" => 2,
              "full_sale_price" => 750.0,
              "title" => "Товар",
              "sku" => "SKU-INS-1"
            }
          ]
        }

        result = Import.call(insale: @insale, payload: payload)

        assert result.order.present?
        assert result.created
        assert_equal "insales", result.order.source
        assert_equal "1001", result.order.insales_order_id
        assert_equal "5001", result.order.number
        assert_equal 1500.0, result.order.total_sum.to_f
        assert_equal "RUB", result.order.currency
        assert_equal @status.id, result.order.order_status_id
        assert_equal 1, result.order.order_items.size
        assert_equal @variant.id, result.order.order_items.first.variant_id
        assert_equal "buyer@example.com", result.order.client.email
      end

      test "updates existing order by insales_order_id" do
        existing = Order.create!(
          source: "insales",
          insale: @insale,
          insales_order_id: "1001",
          order_status: @status
        )

        payload = {
          "id" => 1001,
          "number" => 5002,
          "order_lines" => [
            { "variant_id" => 42, "quantity" => 1, "full_sale_price" => 100.0, "sku" => "SKU-INS-1" }
          ]
        }

        result = Import.call(insale: @insale, payload: payload)

        assert_not result.created
        assert_equal existing.id, result.order.id
        assert_equal "5002", result.order.reload.number
      end
    end
  end
end
