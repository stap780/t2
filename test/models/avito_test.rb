# frozen_string_literal: true

require "test_helper"

class AvitoTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  test "requires profileid" do
    avito = Avito.new(title: "A", api_id: "id-1", api_secret: "sec-1")
    def avito.assign_test_profileid; end

    assert_not avito.valid?
    assert avito.errors[:profileid].present?
  end

  test "requires unique profileid" do
    Avito.create!(title: "A", api_id: "id-1", api_secret: "sec-1", profileid: 71_941_621)
    duplicate = Avito.new(title: "B", api_id: "id-2", api_secret: "sec-2", profileid: 71_941_621)
    def duplicate.assign_test_profileid; end

    assert_not duplicate.valid?
    assert duplicate.errors[:profileid].present?
  end
end
