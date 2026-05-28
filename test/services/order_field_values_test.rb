# frozen_string_literal: true

require "test_helper"

class OrderFieldValuesTest < ActiveSupport::TestCase
  test "resolves order tracking number by source key" do
    order = Order.new(tracking_number: "TRACK-1")

    assert_equal "TRACK-1", OrderFieldValues.call(order:, source_key: "order.tracking_number")
  end

  test "resolves client name" do
    client = Client.new(name: "Иван")
    order = Order.new(client: client)

    assert_equal "Иван", OrderFieldValues.call(order:, source_key: "client.name")
  end
end
