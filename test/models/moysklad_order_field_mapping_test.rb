# frozen_string_literal: true

require "test_helper"

class MoyskladOrderFieldMappingTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "validates source_key inclusion" do
    moysklad = Moysklad.new(api_key: "k", api_password: "p")
    moysklad.save!(validate: false)

    mapping = MoyskladOrderFieldMapping.new(
      moysklad: moysklad,
      source_key: "invalid",
      ms_attribute_href: "https://api.moysklad.ru/api/remap/1.2/entity/customerorder/metadata/attributes/1"
    )
    assert_not mapping.valid?
    assert_includes mapping.errors[:source_key], I18n.t("errors.messages.inclusion")
  end
end
