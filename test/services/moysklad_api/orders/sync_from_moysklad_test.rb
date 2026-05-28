# frozen_string_literal: true

require "test_helper"

module MoyskladApi
  module Orders
    class SyncFromMoyskladTest < ActiveSupport::TestCase
      test "returns error when order is not linked to moysklad" do
        moysklad = Moysklad.create!(api_key: "k", api_password: "p")
        order = ::Order.new(source: "insales", number: "1")

        result = SyncFromMoysklad.call(order: order, moysklad: moysklad)

        assert_not result[:success]
        assert_equal "not_linked_to_moysklad", result[:error]
      end

      test "fetches order and runs sync from webhook" do
        moysklad = Moysklad.create!(api_key: "k", api_password: "p")
        order = ::Order.create!(
          source: "insales",
          number: "1",
          moysklad_order_id: "ms-uuid-1"
        )
        order_json = { "name" => "MS-1", "meta" => { "href" => "https://x/customerorder/ms-uuid-1" } }

        MoyskladApi::CustomerOrder.stub(:fetch, order_json) do
          SyncFromWebhook.stub(:call, ->(**) { true }) do
            result = SyncFromMoysklad.call(order: order, moysklad: moysklad)
            assert result[:success]
          end
        end
      end
    end
  end
end
