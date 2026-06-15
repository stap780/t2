# frozen_string_literal: true

require "test_helper"

module AvitoApi
  module Orders
    class ListTest < ActiveSupport::TestCase
      test "query_params repeats statuses and supports ids" do
        avito = Avito.new(id: 1)
        list = List.new(avito:, params: {})

        query = list.send(
          :query_params,
          {
            statuses: %w[ready_to_ship in_transit],
            ids: %w[123 456],
            page: 2,
            limit: 20,
            dateFrom: 1_767_148_800
          }
        )

        assert_equal(
          {
            statuses: %w[ready_to_ship in_transit],
            page: 2,
            limit: 20,
            ids: %w[123 456],
            dateFrom: 1_767_148_800
          },
          query
        )
      end

      test "active statuses exclude closed and canceled" do
        List::CLOSED_STATUSES.each do |status|
          assert_not_includes List::ACTIVE_STATUSES, status
        end
      end

      test "explicit page fetches single page only" do
        avito = Avito.new(id: 1)
        list = List.new(avito:, params: { statuses: %w[ready_to_ship], page: 1 })

        pages_requested = []
        list.stub(:fetch_page, ->(params) {
          pages_requested << params[:page] || params["page"]
          { orders: [{ "id" => "1", "status" => "ready_to_ship" }], has_more: true }
        }) do
          result = list.call
          assert_equal 1, result.size
          assert_equal [1], pages_requested
        end
      end
    end
  end
end
