# frozen_string_literal: true

require "test_helper"

class ExportFilterRuleTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    @user = User.create!(
      email_address: "export-rule-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    )
    @export = Export.create!(
      name: "Rule export",
      format: "csv",
      status: "pending",
      user: @user,
      export_columns_attributes: [{ field_key: "id" }]
    )
  end

  test "insale rule is valid with rule_value and without property" do
    rule = @export.export_filter_rules.build(
      rule_key: ExportFilterRule::RULE_KEY_INSALE,
      rule_condition: "eq",
      rule_value: "yes"
    )

    assert rule.valid?
    assert rule.integration_rule?
  end

  test "feature rule requires property and characteristic" do
    rule = @export.export_filter_rules.build(
      rule_key: ExportFilterRule::RULE_KEY_FEATURE,
      rule_condition: "eq"
    )

    refute rule.valid?
    assert_includes rule.errors.attribute_names, :property_id
  end

  test "assign_from_field_selector sets integration rule" do
    rule = @export.export_filter_rules.build(rule_key: ExportFilterRule::RULE_KEY_FEATURE, rule_condition: "eq")
    rule.assign_from_field_selector!("insale")

    assert rule.insale_rule?
    assert_equal "yes", rule.rule_value
  end

  test "integration_binding_present combines predicate and value" do
    rule = @export.export_filter_rules.build(
      rule_key: ExportFilterRule::RULE_KEY_INSALE,
      rule_condition: "eq",
      rule_value: "yes"
    )
    assert rule.integration_binding_present?

    rule.rule_value = "no"
    refute rule.integration_binding_present?

    rule.rule_condition = "not_eq"
    assert rule.integration_binding_present?
  end
end
