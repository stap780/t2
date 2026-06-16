# frozen_string_literal: true

require "test_helper"

module MoyskladApi
  module Counterparty
    class SyncToClientTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      setup do
        @moysklad = Moysklad.create!(api_key: "key-#{SecureRandom.hex(4)}", api_password: "secret")
        @uuid = "349a07d3-56bb-11f1-0a80-08d0003df5fb"
        @agent_href = EntityHref.counterparty(@uuid)
      end

      test "creates client and varbind from expanded agent" do
        order_json = {
          "agent" => {
            "meta" => { "href" => @agent_href, "type" => "counterparty" },
            "name" => "Иван Петров",
            "email" => "ivan-#{SecureRandom.hex(4)}@example.com",
            "phone" => "+7 (900) 111-22-33"
          }
        }

        client = SyncToClient.call(moysklad: @moysklad, order_json: order_json)

        assert client.persisted?
        assert_equal "Иван Петров", client.name
        assert_equal "79001112233", client.phone
        assert Varbind.exists?(record: client, bindable: @moysklad, value: @uuid)
      end

      test "uses placeholder email when agent has no email" do
        order_json = {
          "agent" => {
            "meta" => { "href" => @agent_href },
            "name" => "Без email"
          }
        }

        client = SyncToClient.call(moysklad: @moysklad, order_json: order_json)

        assert_equal "ms-#{@uuid}@moysklad.local", client.email
      end

      test "finds existing client by varbind and updates fields" do
        existing = ::Client.create!(
          name: "Старое имя",
          email: "existing-#{SecureRandom.hex(4)}@example.com",
          phone: "0"
        )
        Varbind.create!(record: existing, bindable: @moysklad, value: @uuid)

        order_json = {
          "agent" => {
            "meta" => { "href" => @agent_href },
            "name" => "Новое имя",
            "phone" => "79009998877"
          }
        }

        client = SyncToClient.call(moysklad: @moysklad, order_json: order_json)

        assert_equal existing.id, client.id
        assert_equal "Новое имя", client.reload.name
        assert_equal "79009998877", client.phone
        assert_equal 1, ::Client.count
      end

      test "fetches counterparty when agent is meta only" do
        order_json = {
          "agent" => {
            "meta" => { "href" => @agent_href, "type" => "counterparty" }
          }
        }
        fetched = {
          "name" => "Из API",
          "email" => "api-#{SecureRandom.hex(4)}@example.com",
          "phone" => "79001112233"
        }

        with_singleton_stub(MoyskladApi::Client, :get_json, ->(*) { fetched }) do
          client = SyncToClient.call(moysklad: @moysklad, order_json: order_json)

          assert_equal "Из API", client.name
          assert_equal fetched["email"], client.email
        end
      end

      test "returns nil when agent missing" do
        assert_nil SyncToClient.call(moysklad: @moysklad, order_json: {})
      end
    end
  end
end
