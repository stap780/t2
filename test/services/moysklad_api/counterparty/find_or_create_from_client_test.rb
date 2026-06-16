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
            assert_equal @client.id, result[:client].id
            assert Varbind.exists?(record: @client, bindable: @moysklad, value: "new-uuid-123")
          end
        end
      end

      test "reuses client that already owns counterparty varbind" do
        uuid = "b7df7f61-689b-11f1-0a80-0099009df912"
        href = EntityHref.counterparty(uuid)
        canonical = ::Client.create!(
          name: "Канонический",
          email: "canonical-#{SecureRandom.hex(4)}@example.com",
          phone: "79001112233"
        )
        Varbind.create!(record: canonical, bindable: @moysklad, value: uuid)

        duplicate = ::Client.create!(
          name: "Дубликат Avito",
          email: "avito-79001112233@avito.local",
          phone: "79001112233"
        )

        with_singleton_stub(MoyskladApi::Client, :get_json, ->(*) { { "rows" => [] } }) do
          with_singleton_stub(MoyskladApi::Client, :post_json, ->(*) { { "meta" => { "href" => href } } }) do
            result = FindOrCreateFromClient.call(moysklad: @moysklad, client: duplicate)

            assert result[:success]
            assert_equal href, result[:href]
            assert_equal canonical.id, result[:client].id
            assert_not Varbind.exists?(record: duplicate, bindable: @moysklad)
          end
        end
      end
    end
  end
end
