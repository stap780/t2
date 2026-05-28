# frozen_string_literal: true

require "test_helper"

module MoyskladApi
  module Counterparty
    class FindOrCreateFromClientTest < ActiveSupport::TestCase
      self.fixture_table_names = []
      setup do
        @moysklad = Moysklad.create!(api_key: "key-#{SecureRandom.hex(4)}", api_password: "secret")
        @client = ::Client.create!(
          name: "Покупатель",
          email: "buyer-#{SecureRandom.hex(4)}@example.com",
          phone: "79001234567"
        )
      end

      test "returns href from existing varbind without api call" do
        uuid = "349a07d3-56bb-11f1-0a80-08d0003df5fb"
        Varbind.create!(record: @client, bindable: @moysklad, value: uuid)

        result = FindOrCreateFromClient.call(moysklad: @moysklad, client: @client)

        assert result[:success]
        assert_equal EntityHref.counterparty(uuid), result[:href]
      end

      test "creates varbind with uuid after counterparty create" do
        href = "#{Api::API_BASE}/entity/counterparty/new-uuid-123"
        with_singleton_stub(MoyskladApi::Client, :get_json, ->(*) { { "rows" => [] } }) do
          with_singleton_stub(MoyskladApi::Client, :post_json, ->(*) { { "meta" => { "href" => href } } }) do
            result = FindOrCreateFromClient.call(moysklad: @moysklad, client: @client)

            assert result[:success]
            assert_equal href, result[:href]
            assert Varbind.exists?(record: @client, bindable: @moysklad, value: "new-uuid-123")
          end
        end
      end
    end
  end
end
