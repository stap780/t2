# frozen_string_literal: true

require "test_helper"

class OrderTest < ActiveSupport::TestCase
  test "validates source inclusion" do
    order = Order.new(source: "invalid")
    assert_not order.valid?
    assert order.errors[:source].present?
  end

  test "avito_channel when avito_order_id present" do
    order = Order.new(source: "moysklad", avito_order_id: "123")
    assert order.avito_channel?
  end
end
