# frozen_string_literal: true

require "test_helper"

module AvitoApi
  class ProductRealIdTest < ActiveSupport::TestCase
    test "export_real_id uses product id by default" do
      product = Product.create!(title: "P1")
      assert_equal product.id.to_s, ProductRealId.export_real_id(product)
    end

    test "find_product by id" do
      product = Product.create!(title: "P2")
      assert_equal product, ProductRealId.find_product(product.id.to_s)
    end
  end
end
