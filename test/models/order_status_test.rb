# frozen_string_literal: true

require "test_helper"

class OrderStatusTest < ActiveSupport::TestCase
  test "validates unique code" do
    OrderStatus.create!(code: "new", title: "Новый", position: 1)
    duplicate = OrderStatus.new(code: "new", title: "Другой", position: 2)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "generates code from title on create" do
    status = OrderStatus.create!(title: "Тестовый", color: "#cccccc", position: 99)

    assert_equal "testovyy", status.code
  end

  test "generates unique code when collision" do
    OrderStatus.create!(code: "oplachen", title: "Старый", position: 1)
    status = OrderStatus.create!(title: "Оплачен", position: 2)

    assert_match(/\Aoplachen_\d+\z/, status.code)
  end
end
