# frozen_string_literal: true

require "test_helper"

class ExportColumnTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @user = User.create!(
      email_address: "export-col-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @export = Export.create!(
      name: "CSV export",
      format: "csv",
      status: "pending",
      user: @user
    )
  end

  test "header_title uses label when present" do
    column = @export.export_columns.create!(field_key: "title", label: "Название в файле")
    assert_equal "Название в файле", column.header_title
  end

  test "header_title falls back to field_label" do
    column = @export.export_columns.create!(field_key: "title")
    assert_equal Export.field_label("title"), column.header_title
  end

  test "export requires at least one column for csv when persisted" do
    export = Export.create!(
      name: "Empty columns",
      format: "csv",
      status: "pending",
      user: @user
    )
    assert_not export.valid?
    assert_includes export.errors[:export_columns], I18n.t("exports.errors.columns_required")

    export.export_columns.create!(field_key: "id")
    assert export.valid?
  end

  test "xml export does not require columns" do
    export = Export.create!(
      name: "XML",
      format: "xml",
      status: "pending",
      user: @user,
      layout_template: "<x>{{ items_xml }}</x>",
      item_template: "<i/>"
    )
    assert export.valid?
  end
end
