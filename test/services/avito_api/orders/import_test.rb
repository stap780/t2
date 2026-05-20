# frozen_string_literal: true

require "test_helper"

module AvitoApi
  module Orders
    class ImportTest < ActiveSupport::TestCase
      setup do
        @avito = Avito.create!(
          title: "Test Avito",
          api_id: "client-id-#{SecureRandom.hex(4)}",
          api_secret: "secret-#{SecureRandom.hex(4)}"
        )
        @status = OrderStatus.create!(code: "new", title: "Новый", position: 1)
        @product = Product.create!(title: "Товар")
        @variant = @product.variants.create!(quantity: 1, price: 100, sku: "SKU1")
        Varbind.create!(
          record: @variant,
          bindable: @avito,
          value: "item-123"
        )
      end

      test "imports order with matched item" do
        payload = {
          "id" => "55000000051131229",
          "marketplaceId" => "70000000429007323",
          "items" => [
            {
              "id" => "item-123",
              "count" => 2,
              "prices" => { "price" => 1500.0 }
            }
          ]
        }

        result = Import.call(avito: @avito, payload: payload)

        assert result.order.present?
        assert result.created
        assert_equal "avito", result.order.source
        assert_equal "55000000051131229", result.order.avito_order_id
        assert_equal "70000000429007323", result.order.avito_marketplace_id
        assert_equal 1, result.order.order_items.count
        assert_equal @variant.id, result.order.order_items.first.variant_id
      end

      test "skips when no items match varbind" do
        payload = {
          "marketplaceId" => "mp-200",
          "items" => [{ "id" => "unknown", "count" => 1, "prices" => { "price" => 100 } }]
        }

        result = Import.call(avito: @avito, payload: payload)

        assert_equal "no_matched_items", result.error
      end
    end
  end
end
