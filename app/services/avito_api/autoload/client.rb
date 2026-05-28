# frozen_string_literal: true

require "rest-client"

module AvitoApi
  module Autoload
    class Client
      def initialize(avito:)
        @avito = avito
      end

      def get(path, params: {})
        token = AvitoApi::Auth.access_token(@avito)
        return nil if token.blank?

        response = RestClient.get(
          "#{AvitoApi::Auth::API_BASE}#{path}",
          {
            Authorization: "Bearer #{token}",
            accept: "application/json",
            params: params.compact
          }
        )
        JSON.parse(response.body)
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "[AvitoApi::Autoload::Client] GET #{path} #{e.http_code}: #{e.http_body}"
        nil
      rescue JSON::ParserError, StandardError => e
        Rails.logger.error "[AvitoApi::Autoload::Client] GET #{path} #{e.class}: #{e.message}"
        nil
      end
    end
  end
end
