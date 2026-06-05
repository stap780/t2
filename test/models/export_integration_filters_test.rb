# frozen_string_literal: true

require "test_helper"

class ExportIntegrationFiltersTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    BarcodeCounter.find_or_create_by!(id: 1) { |c| c.last_value = 900_000 }
    @user = User.create!(
      email_address: "export-filters-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @insale = Insale.create!(
      api_key: "key-#{SecureRandom.hex(4)}",
      api_password: "pass",
      api_link: "https://example.insales.ru"
    )
    @moysklad = Moysklad.create!(
      api_key: "key-#{SecureRandom.hex(4)}",
      api_password: "secret"
    )

    @with_insale = create_exportable_product(title: "With InSale")
    @with_insale.variants.first.bindings.create!(bindable: @insale, value: "ins-1")

    @without_insale = create_exportable_product(title: "Without InSale")

    @export = Export.create!(
      name: "Integration filters export",
      format: "xml",
      status: "pending",
      user: @user,
      layout_template: "<root>{{ items_xml }}</root>",
      item_template: "<item/>"
    )
  end

  test "apply_integration_filters with insale eq yes keeps products with insale binding" do
    @export.export_filter_rules.create!(
      rule_key: ExportFilterRule::RULE_KEY_INSALE,
      rule_condition: "eq",
      rule_value: "yes"
    )

    ids = @export.send(:apply_integration_filters, Product.active.yes_quantity.yes_price).pluck(:id)

    assert_includes ids, @with_insale.id
    refute_includes ids, @without_insale.id
  end

  test "apply_integration_filters with moysklad eq no excludes products with moysklad binding" do
    with_ms = create_exportable_product(title: "With MS")
    with_ms.variants.first.bindings.create!(bindable: @moysklad, value: "ms-1")

    @export.export_filter_rules.create!(
      rule_key: ExportFilterRule::RULE_KEY_MOYSKLAD,
      rule_condition: "eq",
      rule_value: "no"
    )

    ids = @export.send(:apply_integration_filters, Product.active.yes_quantity.yes_price).pluck(:id)

    refute_includes ids, with_ms.id
    assert_includes ids, @without_insale.id
  end

  private

  def create_exportable_product(title:)
    product = Product.create!(title: title, status: "active")
    product.variants.create!(quantity: 2, price: 100)
    product
  end
end
