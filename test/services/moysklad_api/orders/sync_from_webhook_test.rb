# frozen_string_literal: true

require "test_helper"

module MoyskladApi
  module Orders
    class SyncFromWebhookTest < ActiveSupport::TestCase
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

      private

      def sample_order_json(state_href:, external_code: nil)
        {
          "meta" => { "href" => "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/ms-uuid-1" },
          "name" => "00042",
          "sum" => 10_000,
          "externalCode" => external_code,
          "description" => "Комментарий",
          "state" => { "meta" => { "href" => state_href } },
          "positions" => { "rows" => [] }
        }
      end
    end
  end
end
