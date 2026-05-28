# frozen_string_literal: true

require "test_helper"

class OrderTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "comments_description joins comment bodies" do
    order = Order.create!(
      source: "avito",
      avito_id: Avito.create!(title: "A", api_id: "c", api_secret: "s").id,
      avito_order_id: "1"
    )
    order.comments.create!(body: "строка 1")
    order.comments.create!(body: "строка 2")

    assert_equal "строка 1\n\nстрока 2", order.comments_description
  end

  test "comments_description is empty without comments" do
    order = Order.create!(source: "insales", insales_order_id: "1")

    assert_equal "", order.comments_description
  end

  test "upsert_prefixed_note creates and updates by prefix" do
    order = Order.create!(source: "insales", insales_order_id: "2")
    prefix = "InSales: shop\n"

    order.upsert_prefixed_note("InSales: shop\nстрока 1", prefix: prefix)
    assert_equal 1, order.comments.count

    order.upsert_prefixed_note("InSales: shop\nстрока 2", prefix: prefix)
    assert_equal 1, order.comments.count
    assert_includes order.comments.first.body, "строка 2"
  end
end
