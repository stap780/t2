# frozen_string_literal: true

require "rest-client"

module AvitoApi
  module Orders
    class List
      ORDERS_PATH = "/order-management/1/orders".freeze
      CLOSED_STATUSES = %w[closed canceled].freeze

      # Статусы Order Management API, кроме closed/canceled.
      ACTIVE_STATUSES = %w[
        on_confirmation
        ready_to_ship
        in_transit
        delivered
        on_return
      ].freeze

      def self.call(avito:, params: {})
        merged = { statuses: ACTIVE_STATUSES }.merge(params.compact)
        new(avito:, params: merged).call
      end

      def initialize(avito:, params: {})
        @avito = avito
        @params = params
      end

      def call
        return filter_closed(fetch_page(@params)[:orders]) if explicit_page?

        orders = []
        page = 1

        loop do
          body = fetch_page(@params.merge(page: page))
          batch = body[:orders]
          break if batch.empty?

          orders.concat(batch)
          break unless body[:has_more]

          page += 1
        end

        filter_closed(orders)
      end

      private

      def fetch_page(params)
        token = AvitoApi::Auth.access_token(@avito)
        return empty_page if token.blank?

        response = RestClient.get(
          "#{AvitoApi::Auth::API_BASE}#{ORDERS_PATH}",
          {
            Authorization: "Bearer #{token}",
            "Content-Type" => "application/json",
            params: query_params(params)
          }
        )
        body = JSON.parse(response.body)
        {
          orders: body["orders"] || body["result"] || [],
          has_more: body["hasMore"] == true
        }
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "[AvitoApi::Orders::List] #{e.http_code}: #{e.http_body}"
        empty_page
      rescue JSON::ParserError, StandardError => e
        Rails.logger.error "[AvitoApi::Orders::List] #{e.class}: #{e.message}"
        empty_page
      end

      def empty_page
        { orders: [], has_more: false }
      end

      def explicit_page?
        @params.key?(:page) || @params.key?("page")
      end

      def filter_closed(orders)
        orders.reject { |order| CLOSED_STATUSES.include?(order["status"]) }
      end

      def query_params(params)
        raw = params.compact.dup
        query = {}

        statuses = Array(raw.delete(:statuses) || raw.delete("statuses"))
        query[:statuses] = statuses if statuses.any?

        limit = raw.delete(:limit) || raw.delete("limit")
        query[:limit] = limit if limit.present?

        page = raw.delete(:page) || raw.delete("page")
        query[:page] = page if page.present?

        ids = Array(raw.delete(:ids) || raw.delete("ids"))
        query[:ids] = ids if ids.any?

        raw.each { |key, value| query[key.to_sym] = value }
        query
      end
    end
  end
end
