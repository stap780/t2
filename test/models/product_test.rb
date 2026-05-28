# frozen_string_literal: true

require "test_helper"

class ProductTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @avito1 = Avito.create!(
      title: "Avito 1",
      api_id: "client-#{SecureRandom.hex(4)}",
      api_secret: "secret-#{SecureRandom.hex(4)}"
    )
    @avito2 = Avito.create!(
      title: "Avito 2",
      api_id: "client-#{SecureRandom.hex(4)}",
      api_secret: "secret-#{SecureRandom.hex(4)}"
    )
    Product.avito_filter_scope_names

    @product_avito1 = Product.create!(title: "Only Avito 1")
    @product_avito1.bindings.create!(bindable: @avito1, value: "111")

    @product_avito2 = Product.create!(title: "Only Avito 2")
    @product_avito2.bindings.create!(bindable: @avito2, value: "222")

    @product_both = Product.create!(title: "Both Avito")
    @product_both.bindings.create!(bindable: @avito1, value: "333")
    @product_both.bindings.create!(bindable: @avito2, value: "444")

    @product_none = Product.create!(title: "No Avito")
  end

  test "with_avito scope filters by cabinet" do
    scope = Product.with_avito_scope_name(@avito1.id)
    ids = Product.public_send(scope).pluck(:id)

    assert_equal [@product_avito1.id, @product_both.id].sort, ids.sort
  end

  test "without_avito scope excludes cabinet bindings" do
    scope = Product.without_avito_scope_name(@avito1.id)
    ids = Product.public_send(scope).pluck(:id)

    assert_equal [@product_avito2.id, @product_none.id].sort, ids.sort
  end

  test "ransack with_avito scope" do
    scope = Product.with_avito_scope_name(@avito1.id)
    result = Product.ransack(scope => "1").result

    assert_equal [@product_avito1.id, @product_both.id].sort, result.pluck(:id).sort
  end

  test "ransack without_avito scope" do
    scope = Product.without_avito_scope_name(@avito2.id)
    result = Product.ransack(scope => "1").result

    assert_equal [@product_avito1.id, @product_none.id].sort, result.pluck(:id).sort
  end

  test "ransack ANDs multiple with_avito scopes" do
    with1 = Product.with_avito_scope_name(@avito1.id)
    with2 = Product.with_avito_scope_name(@avito2.id)
    result = Product.ransack(with1 => "1", with2 => "1").result

    assert_equal [@product_both.id], result.pluck(:id)
  end

  test "avito filter scope names include all cabinets" do
    names = Product.avito_filter_scope_names

    assert_includes names, Product.with_avito_scope_name(@avito1.id)
    assert_includes names, Product.without_avito_scope_name(@avito1.id)
    assert_includes names, Product.with_avito_scope_name(@avito2.id)
    assert_includes names, Product.without_avito_scope_name(@avito2.id)
  end

  test "cannot destroy product when variant has order items" do
    BarcodeCounter.find_or_create_by!(id: 1) { |c| c.last_value = 900_000 }
    product = Product.create!(title: "In order")
    variant = product.variants.create!(quantity: 1, price: 100, sku: "ORD1")
    order = Order.create!(source: "insales", insales_order_id: SecureRandom.uuid)
    OrderItem.create!(order: order, variant: variant, quantity: 1, price: 100)

    assert_not product.destroy
    assert_includes product.errors[:base].first, "заказа"
    assert Product.exists?(product.id)
  end
end
