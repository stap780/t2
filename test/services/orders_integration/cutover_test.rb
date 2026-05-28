# frozen_string_literal: true

require "test_helper"

class OrdersIntegration::CutoverTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  setup do
    Moysklad.delete_all
    @moysklad = Moysklad.create!(
      api_key: "key",
      api_password: "secret",
      orders_integration_start_at: Time.zone.parse("2026-05-27 12:00:00")
    )
  end

  test "disabled when cutover not set" do
    @moysklad.update!(orders_integration_start_at: nil)

    assert_not OrdersIntegration::Cutover.enabled?
    assert_not OrdersIntegration::Cutover.skip?(
      known_in_app: false,
      source_created_at: Time.zone.parse("2020-01-01")
    )
  end

  test "skips unknown order created before cutover" do
    assert OrdersIntegration::Cutover.skip?(
      known_in_app: false,
      source_created_at: Time.zone.parse("2026-05-27 11:00:00")
    )
  end

  test "does not skip unknown order created at or after cutover" do
    assert_not OrdersIntegration::Cutover.skip?(
      known_in_app: false,
      source_created_at: Time.zone.parse("2026-05-27 12:00:00")
    )
    assert_not OrdersIntegration::Cutover.skip?(
      known_in_app: false,
      source_created_at: Time.zone.parse("2026-05-28 10:00:00")
    )
  end

  test "does not skip known order even if old" do
    assert_not OrdersIntegration::Cutover.skip?(
      known_in_app: true,
      source_created_at: Time.zone.parse("2020-01-01")
    )
  end

  test "does not skip when source date missing" do
    assert_not OrdersIntegration::Cutover.skip?(
      known_in_app: false,
      source_created_at: nil
    )
  end

  test "avito_date_from_param returns iso8601 utc" do
    assert_equal @moysklad.orders_integration_start_at.utc.iso8601,
                 OrdersIntegration::Cutover.avito_date_from_param
  end

  test "parse_moysklad_time parses MS datetime string" do
    parsed = OrdersIntegration::Cutover.parse_moysklad_time("2026-05-27 11:30:00")
    assert_equal 2026, parsed.year
    assert_equal 5, parsed.month
    assert_equal 27, parsed.day
    assert_equal 11, parsed.hour
  end
end
