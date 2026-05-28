# frozen_string_literal: true

require "test_helper"

module AvitoApi
  module Orders
    class ApplyTransitionTest < ActiveSupport::TestCase
      test "skips when transition not in allowed list" do
        avito = Avito.create!(
          title: "Avito",
          api_id: "c-#{SecureRandom.hex(4)}",
          api_secret: "s-#{SecureRandom.hex(4)}"
        )
        status = OrderStatus.create!(code: "paid", title: "Оплачен", position: 1)
        mapping = AvitoOrderStatusMapping.create!(avito:, order_status: status, avito_status: "confirm")
        mapping.update_column(:avito_status, "shipped")
        order = Order.create!(
          source: "avito",
          avito: avito,
          avito_order_id: "55000000051131229",
          order_status: status
        )

        result = ApplyTransition.call(order: order)

        assert_equal false, result[:success]
        assert_equal "invalid_transition", result[:error]
      end
    end
  end
end
