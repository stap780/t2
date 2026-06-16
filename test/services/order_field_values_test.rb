# frozen_string_literal: true

require "test_helper"

class OrderFieldValuesTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "resolves order tracking number by source key" do
    order = Order.new(tracking_number: "TRACK-1")

    assert_equal "TRACK-1", OrderFieldValues.call(order:, source_key: "order.tracking_number")
  end

  test "resolves client name" do
    client = Client.new(name: "Иван")
    order = Order.new(client: client)

    assert_equal "Иван", OrderFieldValues.call(order:, source_key: "client.name")
  end

  test "resolves integration name via OrderIntegrationName" do
    avito = Avito.create!(title: "Магазин Avito", api_id: "id-#{SecureRandom.hex(4)}", api_secret: "sec")
    order = Order.new(source: "avito", avito: avito)

    assert_equal "Магазин Avito", OrderFieldValues.call(order:, source_key: "integration.name")
  end
end
