# frozen_string_literal: true

require "test_helper"

class ProductIntegrationLinksTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @product = Product.create!(title: "Товар")
    BarcodeCounter.find_or_create_by!(id: 1) { |c| c.last_value = 900_000 }
    @variant = @product.variants.create!(quantity: 1, price: 100, sku: "SKU1")
    @variant.update_column(:barcode, "000000900001")
    @avito = Avito.create!(
      title: "Кабинет Avito",
      api_id: "client-#{SecureRandom.hex(4)}",
      api_secret: "secret-#{SecureRandom.hex(4)}"
    )
  end

  test "shows avito link from product-level varbind" do
    @product.bindings.create!(bindable: @avito, value: "7890403963")

    links = ProductIntegrationLinks.new(@product).call

    assert_equal 1, links.size
    assert_equal "avito-#{@avito.id}", links.first.key
    assert_equal "Кабинет Avito", links.first.label
    assert_equal "https://www.avito.ru/7890403963", links.first.url
    assert_includes links.first.css, "amber"
  end

  test "ignores avito binding on variant" do
    @variant.bindings.create!(bindable: @avito, value: "legacy-ad")

    assert_empty ProductIntegrationLinks.new(@product).call
  end

  test "shows avito link even when variant has no barcode" do
    @variant.update_column(:barcode, nil)
    @product.bindings.create!(bindable: @avito, value: "7890403963")

    links = ProductIntegrationLinks.new(@product).call

    assert_equal 1, links.size
    assert_equal "https://www.avito.ru/7890403963", links.first.url
  end

  test "avito label falls back when cabinet missing" do
    avito_id = @avito.id
    @product.bindings.create!(bindable: @avito, value: "1234567890")
    @avito.destroy

    links = ProductIntegrationLinks.new(@product).call

    assert_equal 1, links.size
    assert_equal "Av.#{avito_id}", links.first.label
    assert_equal "https://www.avito.ru/1234567890", links.first.url
  end
end
