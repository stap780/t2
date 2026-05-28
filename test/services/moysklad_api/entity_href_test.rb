# frozen_string_literal: true

require "test_helper"

module MoyskladApi
  class EntityHrefTest < ActiveSupport::TestCase
    self.fixture_table_names = []
    test "builds counterparty href from uuid" do
      uuid = "349a07d3-56bb-11f1-0a80-08d0003df5fb"
      assert_equal "#{Api::API_BASE}/entity/counterparty/#{uuid}", EntityHref.counterparty(uuid)
    end

    test "extracts uuid from full href" do
      href = "https://api.moysklad.ru/api/remap/1.2/entity/counterparty/349a07d3-56bb-11f1-0a80-08d0003df5fb"
      assert_equal "349a07d3-56bb-11f1-0a80-08d0003df5fb", EntityHref.extract_id(href, entity: "counterparty")
    end

    test "returns plain uuid as-is" do
      uuid = "349a07d3-56bb-11f1-0a80-08d0003df5fb"
      assert_equal uuid, EntityHref.extract_id(uuid, entity: "counterparty")
    end
  end
end
