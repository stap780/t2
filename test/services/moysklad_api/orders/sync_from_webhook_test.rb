# frozen_string_literal: true

require "test_helper"

module MoyskladApi
  module Orders
    class SyncFromWebhookTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      setup do
        @moysklad = Moysklad.create!(api_key: "key", api_password: "secret")
        @order_status = OrderStatus.create!(code: "paid", title: "Оплачен", position: 1)
        @state_href = "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/states/paid"
        MoyskladOrderStatusMapping.create!(
          moysklad_state_href: @state_href,
          moysklad_state_name: "Оплачен",
          order_status: @order_status
        )
      end

      test "creates moysklad office order and applies status mapping" do
        order_json = sample_order_json(state_href: @state_href)

        order = SyncFromWebhook.call(moysklad: @moysklad, order_json: order_json, action: "UPDATE")

        assert_equal "moysklad", order.source
        assert_equal "ms-uuid-1", order.moysklad_order_id
        assert_equal "00042", order.number
        assert_equal 100.0, order.total_sum
        assert_equal @order_status.id, order.order_status_id
        assert_equal @state_href, order.last_moysklad_state_href
      end

      test "links existing order by externalCode id" do
        existing = Order.create!(source: "avito", avito_order_id: "av-1")
        order_json = sample_order_json(
          external_code: existing.id.to_s,
          state_href: @state_href
        )

        order = SyncFromWebhook.call(moysklad: @moysklad, order_json: order_json, action: "UPDATE")

        assert_equal existing.id, order.id
        assert_equal "avito", order.source
        assert_equal "ms-uuid-1", order.moysklad_order_id
      end

      test "skips status update when state unchanged" do
        other_status = OrderStatus.create!(code: "shipped", title: "Отправлен", position: 2)
        order = Order.create!(
          source: "moysklad",
          moysklad_order_id: "ms-uuid-1",
          last_moysklad_state_href: @state_href,
          order_status: other_status
        )
        order_json = sample_order_json(state_href: @state_href)

        SyncFromWebhook.call(moysklad: @moysklad, order_json: order_json, action: "UPDATE")

        assert_equal other_status.id, order.reload.order_status_id
      end

      test "keeps insales order number when syncing from moysklad" do
        order = Order.create!(
          source: "insales",
          insales_order_id: "1483502201",
          number: "15339",
          moysklad_order_id: "ms-uuid-1"
        )
        order_json = sample_order_json(
          external_code: order.id.to_s,
          state_href: @state_href,
          name: "297685"
        )

        SyncFromWebhook.call(moysklad: @moysklad, order_json: order_json, action: "UPDATE")

        assert_equal "15339", order.reload.number
      end

      test "pushes insales status when moysklad state changes" do
        insale = Insale.create!(
          api_link: "shop.insales.ru",
          api_key: "key",
          api_password: "pwd"
        )
        order = Order.create!(
          source: "insales",
          insale: insale,
          insales_order_id: "100",
          number: "15339",
          moysklad_order_id: "ms-uuid-1",
          order_status: @order_status
        )
        InsalesOrderStatusMapping.create!(
          insale: insale,
          order_status: @order_status,
          insales_custom_status_permalink: "shipped",
          insales_financial_status: "paid"
        )
        order_json = sample_order_json(
          external_code: order.id.to_s,
          state_href: @state_href
        )

        with_singleton_stub(Insales::Orders::PushFromOrder, :call, ->(*) { { success: true } }) do
          SyncFromWebhook.call(moysklad: @moysklad, order_json: order_json, action: "UPDATE")
        end
      end

      test "skips unknown order created before integration start" do
        @moysklad.update!(orders_integration_start_at: Time.zone.parse("2026-05-27 12:00:00"))
        order_json = sample_order_json(
          state_href: @state_href,
          created: "2026-05-20 10:00:00"
        )

        order = SyncFromWebhook.call(moysklad: @moysklad, order_json: order_json, action: "UPDATE")

        assert_nil order
        assert_equal 0, Order.count
      end

      test "syncs known order even if created before integration start" do
        @moysklad.update!(orders_integration_start_at: Time.zone.parse("2026-05-27 12:00:00"))
        existing = Order.create!(
          source: "moysklad",
          moysklad_order_id: "ms-uuid-1",
          number: "00001"
        )
        order_json = sample_order_json(
          state_href: @state_href,
          created: "2026-05-20 10:00:00"
        )

        order = SyncFromWebhook.call(moysklad: @moysklad, order_json: order_json, action: "UPDATE")

        assert_equal existing.id, order.id
      end

      private

      def sample_order_json(state_href:, external_code: nil, name: "00042", created: nil)
        {
          "meta" => { "href" => "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/ms-uuid-1" },
          "name" => name,
          "sum" => 10_000,
          "externalCode" => external_code,
          "created" => created,
          "description" => "Комментарий",
          "state" => { "meta" => { "href" => state_href } },
          "positions" => { "rows" => [] }
        }
      end
    end
  end
end
