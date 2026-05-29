# frozen_string_literal: true

require "test_helper"

class ExportProductToHashTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    BarcodeCounter.find_or_create_by!(id: 1) { |c| c.last_value = 900_000 }
    @user = User.create!(
      email_address: "export-hash-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @avito = Avito.create!(
      title: "Export Avito",
      api_id: "client-#{SecureRandom.hex(4)}",
      api_secret: "secret-#{SecureRandom.hex(4)}"
    )
    @product = Product.create!(title: "Товар", status: "active")
    @variant = @product.variants.create!(quantity: 1, price: 100, barcode: "123456")
    @product.bindings.create!(bindable: @avito, value: "avito-item-99")
    @variant.bindings.create!(bindable: @avito, value: "legacy-on-variant")
    @export = Export.new(
      name: "Test export",
      format: "xml",
      status: "pending",
      user: @user,
      layout_template: "<root>{{ items_xml }}</root>",
      item_template: "<item/>"
    )
  end

  test "product_to_hash includes product and variant bindings" do
    hash = @export.send(:product_to_hash, @product.reload)

    assert_equal 1, hash["bindings"].size
    assert_equal "Avito", hash["bindings"].first["bindable_type"]
    assert_equal @avito.id, hash["bindings"].first["bindable_id"]
    assert_equal "avito-item-99", hash["bindings"].first["value"]

    variant_hash = hash["variants"].find { |v| v["id"] == @variant.id }
    assert_equal 1, variant_hash["bindings"].size
    assert_equal "legacy-on-variant", variant_hash["bindings"].first["value"]
  end

  test "flatten_data_for_csv uses features_hash without array fallback" do
    service = ExportService.new(@export)
    row = {
      "id" => "1",
      "title" => "T",
      "features_hash" => { "Марка" => "Audi" },
      "features" => [{ "property" => "Марка", "characteristic" => "BMW" }]
    }

    flattened = service.send(:flatten_data_for_csv, [row]).first

    assert_equal "Audi", flattened["feature_Марка"]
  end
end
