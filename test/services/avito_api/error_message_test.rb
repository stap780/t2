# frozen_string_literal: true

require "test_helper"

module AvitoApi
  class ErrorMessageTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    test "translates known import error code" do
      assert_equal I18n.t("avito_api.errors.no_matched_items"), ErrorMessage.translate("no_matched_items")
    end

    test "passes through unknown error as default" do
      assert_equal "something weird", ErrorMessage.translate("something weird")
    end

    test "translates moysklad order prefix with nested code" do
      message = ErrorMessage.translate("MS order #42: no_matched_items")
      assert_includes message, "42"
      assert_includes message, I18n.t("avito_api.errors.no_matched_items")
    end
  end
end
