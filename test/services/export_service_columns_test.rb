# frozen_string_literal: true

require "test_helper"

class ExportServiceColumnsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    BarcodeCounter.find_or_create_by!(id: 1) { |c| c.last_value = 900_000 }
    @user = User.create!(
      email_address: "export-svc-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @export = Export.create!(
      name: "CSV",
      format: "csv",
      status: "pending",
      user: @user,
      test: true
    )
    @export.export_columns.create!(field_key: "id", label: "ID в выгрузке")
  end

  test "filter_flattened_by_columns uses custom column titles" do
    service = ExportService.new(@export)
    flattened = [{ "id" => "1", "title" => "Товар" }]
    _filtered, field_keys, titles = service.send(:filter_flattened_by_columns, flattened)

    assert_equal %w[id], field_keys
    assert_equal ["ID в выгрузке"], titles
  end

  test "fails when no export columns for csv" do
    ExportColumn.where(export_id: @export.id).delete_all
    @export.reload

    service = ExportService.new(@export)
    ok, = service.call
    assert_not ok
    assert_equal "failed", @export.reload.status
    assert_includes @export.error_message, I18n.t("exports.errors.columns_required")
  end
end
