# frozen_string_literal: true

require "test_helper"

class VarbindTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @avito = Avito.create!(
      title: "Test Avito",
      api_id: "client-id-#{SecureRandom.hex(4)}",
      api_secret: "secret-#{SecureRandom.hex(4)}"
    )
    @product = Product.create!(title: "Product")
    @variant = @product.variants.create!(quantity: 1, price: 100)
  end

  test "product binding message uses товар wording" do
    Varbind.create!(record: @product, bindable: @avito, value: "111")

    duplicate = Varbind.new(record: @product, bindable: @avito, value: "222")
    refute duplicate.valid?
    assert_includes duplicate.errors.full_messages.join, "у товару может быть только одна привязка"
  end

  test "variant binding message uses вариант wording" do
    Varbind.create!(record: @variant, bindable: @avito, value: "111")

    duplicate = Varbind.new(record: @variant, bindable: @avito, value: "222")
    refute duplicate.valid?
    assert_includes duplicate.errors.full_messages.join, "у варианту может быть только одна привязка"
  end
end
