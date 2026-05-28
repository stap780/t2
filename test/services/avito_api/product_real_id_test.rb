# frozen_string_literal: true

require "test_helper"

module AvitoApi
  class ProductRealIdTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    test "export_real_id uses product id by default" do
      product = Product.create!(title: "P1")
      assert_equal product.id.to_s, ProductRealId.export_real_id(product)
    end

    test "export_real_id uses old id when present" do
      product = Product.create!(title: "P1")
      attach_old_id(product, "1711884417")

      assert_equal "1711884417", ProductRealId.export_real_id(product)
    end

    test "find_product by id when old id missing" do
      product = Product.create!(title: "P2")
      assert_equal product, ProductRealId.find_product(product.id.to_s)
    end

    test "find_product prefers old id over product id" do
      other = Product.create!(title: "Other")
      attach_old_id(other, "999")

      product = Product.create!(title: "P3")
      assert_equal other, ProductRealId.find_product("999")
      assert_equal product, ProductRealId.find_product(product.id.to_s)
    end

    test "find_product by old id" do
      product = Product.create!(title: "P4")
      attach_old_id(product, "1711884417")

      assert_equal product, ProductRealId.find_product("1711884417")
    end

    private

    def attach_old_id(product, old_id)
      property = Property.create!(title: ProductRealId::OLD_ID_PROPERTY)
      characteristic = Characteristic.create!(property: property, title: old_id)
      Feature.create!(featureable: product, property: property, characteristic: characteristic)
    end
  end
end
