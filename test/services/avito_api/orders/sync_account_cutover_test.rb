# frozen_string_literal: true

require "test_helper"

module AvitoApi
  module Orders
    class SyncAccountCutoverTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      setup do
        @avito = Avito.create!(
          title: "Test Avito",
          api_id: "client-id",
          api_secret: "secret"
        )
        @cutover = Time.zone.parse("2026-05-27 12:00:00")
        Moysklad.create!(
          api_key: "ms-key",
          api_password: "ms-secret",
          orders_integration_start_at: @cutover
        )
      end

      test "passes dateFrom to List when cutover enabled" do
        captured_params = nil
        list_stub = lambda do |avito:, params:|
          captured_params = params
          []
        end

        with_singleton_stub(AvitoApi::Auth, :access_token, "token") do
          with_singleton_stub(List, :call, list_stub) do
            SyncAccount.call(avito: @avito)
          end
        end

        assert_equal @cutover.to_i, captured_params[:dateFrom]
      end
    end
  end
end
