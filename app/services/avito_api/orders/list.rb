# frozen_string_literal: true

require "rest-client"

module AvitoApi
  module Orders
    class List
      ORDERS_PATH = "/order-management/1/orders".freeze

      def self.call(avito:, params: {})
        new(avito:, params:).call
      end

      def initialize(avito:, params: {})
        @avito = avito
        @params = params
      end

      def call
        token = AvitoApi::Auth.access_token(@avito)
        return [] if token.blank?

        response = RestClient.get(
          "#{AvitoApi::Auth::API_BASE}#{ORDERS_PATH}",
          {
            Authorization: "Bearer #{token}",
            "Content-Type" => "application/json",
            params: @params.compact
          }
        )
        body = JSON.parse(response.body)
        body["orders"] || body["result"] || []
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "[AvitoApi::Orders::List] #{e.http_code}: #{e.http_body}"
        []
      rescue JSON::ParserError, StandardError => e
        Rails.logger.error "[AvitoApi::Orders::List] #{e.class}: #{e.message}"
        []
      end
    end
  end
end
