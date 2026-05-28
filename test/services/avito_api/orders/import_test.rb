# frozen_string_literal: true

require "test_helper"

module AvitoApi
  module Orders
    class ImportTest < ActiveSupport::TestCase
      self.fixture_table_names = []
      setup do
        @avito = Avito.create!(
          title: "Test Avito",
          api_id: "client-id-#{SecureRandom.hex(4)}",
          api_secret: "secret-#{SecureRandom.hex(4)}"
        )
        @status = OrderStatus.create!(code: "new", title: "Новый", position: 1)
        @product = Product.create!(title: "Товар")
        BarcodeCounter.find_or_create_by!(id: 1) { |c| c.last_value = 900_000 }
        @variant = @product.variants.create!(quantity: 1, price: 100, sku: "SKU1")
        Varbind.create!(
          record: @product,
          bindable: @avito,
          value: "7890403963"
        )
      end

      test "imports order with matched item by avitoId on product" do
        payload = {
          "id" => "55000000051131229",
          "marketplaceId" => "70000000429007323",
          "items" => [
            {
              "id" => @product.id.to_s,
              "avitoId" => "7890403963",
              "count" => 2,
              "prices" => { "price" => 1500.0 }
            }
          ]
        }

        result = Import.call(avito: @avito, payload: payload)

        assert result.order.present?
        assert result.created
        assert_equal 1, result.order.comments.count
        assert_includes result.order.comments.first.body, "Авито: #{@avito.title}"
        assert_equal 1, result.order.order_items.count
        assert_equal @variant.id, result.order.order_items.first.variant_id
      end

      test "imports order and creates product link by real_id" do
        Varbind.where(record: @product, bindable: @avito).delete_all

        payload = {
          "id" => "55000000051131229",
          "items" => [
            {
              "id" => @product.id.to_s,
              "avitoId" => "9990001111",
              "count" => 1,
              "prices" => { "price" => 1500.0 }
            }
          ]
        }

        result = Import.call(avito: @avito, payload: payload)

        assert result.order.present?
        assert Varbind.exists?(record: @product, bindable: @avito, value: "9990001111")
      end

      test "imports tracking number from delivery" do
        payload = {
          "id" => "55000000051131229",
          "marketplaceId" => "70000000429007323",
          "delivery" => { "trackingNumber" => "TRACK-123" },
          "items" => [
            {
              "id" => @product.id.to_s,
              "avitoId" => "7890403963",
              "count" => 1,
              "prices" => { "price" => 1500.0 }
            }
          ]
        }

        result = Import.call(avito: @avito, payload: payload)

        assert result.order.present?
        assert_equal "TRACK-123", result.order.tracking_number
      end

      test "creates client from delivery buyerInfo" do
        payload = {
          "id" => "55000000069597521",
          "marketplaceId" => "70000000446935910",
          "delivery" => {
            "buyerInfo" => {
              "fullName" => "непринцева Виктория михайловна",
              "phoneNumber" => "+79998746247"
            }
          },
          "items" => [
            {
              "id" => @product.id.to_s,
              "avitoId" => "7890403963",
              "count" => 1,
              "prices" => { "price" => 1500.0 }
            }
          ]
        }

        messenger_called = false
        with_singleton_stub(AvitoApi::Messenger::FetchChat, :call, ->(*) { messenger_called = true; nil }) do
          result = Import.call(avito: @avito, payload: payload)

          assert result.order.present?
          assert_equal "непринцева", result.order.client.surname
          assert_not messenger_called
        end
      end

      test "creates client from messenger when buyerInfo missing" do
        @avito.update!(profileid: "71941621")
        profile_url = "https://avito.ru/brands/example"
        messenger_buyer = { user_id: "88203907", name: "Алексей Мазин", profile_url: profile_url }

        payload = {
          "id" => "50000000416485062",
          "marketplaceId" => "70000000446216922",
          "delivery" => { "serviceType" => "pvz" },
          "items" => [
            {
              "id" => @product.id.to_s,
              "avitoId" => "7890403963",
              "chatId" => "u2i-test-chat",
              "count" => 1,
              "prices" => { "price" => 1500.0 }
            }
          ]
        }

        with_singleton_stub(AvitoApi::Messenger::FetchChat, :call, ->(*) { messenger_buyer }) do
          result = Import.call(avito: @avito, payload: payload)

          assert result.order.present?
          assert_equal "Алексей Мазин", result.order.client.name
          assert_equal "avito-88203907@placeholder.local", result.order.client.email
          assert Varbind.exists?(record: result.order.client, bindable: @avito, value: "88203907")
          assert_equal 1, result.order.comments.count
          assert_includes result.order.comments.first.body, "Avito профиль: #{profile_url}"
        end
      end

      test "reuses client by avito varbind on second import" do
        @avito.update!(profileid: "71941621")
        existing = Client.create!(
          name: "Алексей Мазин",
          email: "avito-88203907@placeholder.local",
          phone: "0"
        )
        Varbind.create!(record: existing, bindable: @avito, value: "88203907")
        messenger_buyer = { user_id: "88203907", name: "Алексей Мазин", profile_url: "https://avito.ru/brands/example" }

        payload = {
          "id" => "50000000416485063",
          "marketplaceId" => "70000000446216923",
          "items" => [
            {
              "id" => @product.id.to_s,
              "avitoId" => "7890403963",
              "chatId" => "u2i-test-chat-2",
              "count" => 1,
              "prices" => { "price" => 1500.0 }
            }
          ]
        }

        with_singleton_stub(AvitoApi::Messenger::FetchChat, :call, ->(*) { messenger_buyer }) do
          result = Import.call(avito: @avito, payload: payload)

          assert_equal existing.id, result.order.client_id
        end
      end

      test "falls back to generic avito client without buyerInfo and chat" do
        payload = {
          "id" => "55000000051131230",
          "marketplaceId" => "70000000429007324",
          "items" => [
            {
              "id" => @product.id.to_s,
              "avitoId" => "7890403963",
              "count" => 1,
              "prices" => { "price" => 1500.0 }
            }
          ]
        }

        with_singleton_stub(AvitoApi::Messenger::FetchChat, :call, ->(*) { raise "should not call messenger" }) do
          result = Import.call(avito: @avito, payload: payload)

          assert result.order.present?
          assert_equal @avito.title, result.order.client.name
          assert_equal "avito-#{@avito.id}@#{@avito.api_id}.local", result.order.client.email
        end
      end

      test "skips when no items match" do
        payload = {
          "id" => "55000000051131231",
          "marketplaceId" => "mp-200",
          "items" => [{ "id" => "unknown", "avitoId" => "unknown", "count" => 1, "prices" => { "price" => 100 } }]
        }

        result = Import.call(avito: @avito, payload: payload)

        assert_equal "no_matched_items", result.error
      end

      test "legacy variant varbind by real_id still works" do
        Varbind.where(record: @product, bindable: @avito).delete_all
        Varbind.create!(record: @variant, bindable: @avito, value: "legacy-123")

        payload = {
          "id" => "55000000051131229",
          "items" => [{ "id" => "legacy-123", "count" => 1, "prices" => { "price" => 100 } }]
        }

        result = Import.call(avito: @avito, payload: payload)

        assert result.order.present?
        assert_equal @variant.id, result.order.order_items.first.variant_id
      end

      test "skips new order created before integration start" do
        Moysklad.create!(
          api_key: "ms-key",
          api_password: "ms-secret",
          orders_integration_start_at: Time.zone.parse("2026-05-27 12:00:00")
        )
        payload = {
          "id" => "55000000051131299",
          "createdAt" => "2026-05-20T10:00:00Z",
          "items" => [
            { "id" => @product.id.to_s, "avitoId" => "7890403963", "count" => 1, "prices" => { "price" => 100 } }
          ]
        }

        result = Import.call(avito: @avito, payload: payload)

        assert result.skipped
        assert_nil result.order
        assert_equal 0, Order.count
      end

      test "imports existing avito order even if created before integration start" do
        Moysklad.create!(
          api_key: "ms-key",
          api_password: "ms-secret",
          orders_integration_start_at: Time.zone.parse("2026-05-27 12:00:00")
        )
        existing = Order.create!(
          source: "avito",
          avito: @avito,
          avito_order_id: "55000000051131299",
          order_status: @status
        )
        payload = {
          "id" => "55000000051131299",
          "createdAt" => "2026-05-20T10:00:00Z",
          "items" => [
            { "id" => @product.id.to_s, "avitoId" => "7890403963", "count" => 1, "prices" => { "price" => 100 } }
          ]
        }

        result = Import.call(avito: @avito, payload: payload)

        assert result.order.present?
        assert_equal existing.id, result.order.id
      end
    end
  end
end
