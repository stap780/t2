# frozen_string_literal: true

require "test_helper"

module AvitoApi
  class ProductLinkTest < ActiveSupport::TestCase
    setup do
      @avito = Avito.create!(
        title: "Test Avito",
        api_id: "client-id-#{SecureRandom.hex(4)}",
        api_secret: "secret-#{SecureRandom.hex(4)}"
      )
      @product = Product.create!(title: "Товар")
      @variant = @product.variants.create!(quantity: 1, price: 100, sku: "SKU1")
    end

    test "resolve_variant finds product by avitoId binding" do
      Varbind.create!(record: @product, bindable: @avito, value: "7890403963")

      variant = ProductLink.resolve_variant(
        avito: @avito,
        line: { "avitoId" => "7890403963", "id" => "403263" }
      )

      assert_equal @variant, variant
    end

    test "resolve_variant links product by real_id when avitoId missing in bindings" do
      real_id = @product.id.to_s

      variant = ProductLink.resolve_variant(
        avito: @avito,
        line: { "avitoId" => "7890403963", "id" => real_id }
      )

      assert_equal @variant, variant
      assert Varbind.exists?(record: @product, bindable: @avito, value: "7890403963")
    end

    test "link returns conflict when avitoId bound to another product" do
      other = Product.create!(title: "Other")
      Varbind.create!(record: other, bindable: @avito, value: "7890403963")

      result = ProductLink.link!(avito: @avito, product: @product, avito_id: "7890403963")

      assert_equal :conflict, result.status
    end
  end
end
