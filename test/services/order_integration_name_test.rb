# frozen_string_literal: true

require "test_helper"

class OrderIntegrationNameTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "returns avito title" do
    avito = Avito.create!(title: "Кабинет Avito", api_id: "id-#{SecureRandom.hex(4)}", api_secret: "sec")
    order = Order.new(source: "avito", avito: avito)

    assert_equal "Кабинет Avito", OrderIntegrationName.call(order)
  end

  test "returns insale title with api_link fallback" do
    insale = Insale.new(
      api_link: "shop.insales.ru",
      api_key: "key",
      api_password: "pwd"
    )
    insale.valid?
    order = Order.new(source: "insales", insale: insale)

    assert_equal "shop.insales.ru", OrderIntegrationName.call(order)

    insale.title = "My Shop"
    assert_equal "My Shop", OrderIntegrationName.call(order)
  end

  test "returns moysklad title for office orders" do
    Moysklad.create!(api_key: "k", api_password: "p", title: "Склад MS")
    order = Order.new(source: "moysklad")

    assert_equal "Склад MS", OrderIntegrationName.call(order)
  end
end
