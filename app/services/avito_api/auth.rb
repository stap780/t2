# frozen_string_literal: true

require "rest-client"

module AvitoApi
  class Auth
    API_BASE = "https://api.avito.ru".freeze
    CACHE_TTL = 23.hours

    def self.access_token(avito)
      new(avito).access_token
    end

    def initialize(avito)
      @avito = avito
    end

    def access_token
      Rails.cache.fetch(cache_key, expires_in: CACHE_TTL) do
        fetch_token
      end
    end

    def clear_cache!
      Rails.cache.delete(cache_key)
    end

    private

    def cache_key
      "avito_access_token/#{@avito.id}/#{@avito.updated_at.to_i}"
    end

    def fetch_token
      response = RestClient.post(
        "#{API_BASE}/token",
        {
          client_id: @avito.api_id,
          client_secret: @avito.api_secret,
          grant_type: "client_credentials"
        },
        { "Content-Type" => "application/x-www-form-urlencoded" }
      )
      JSON.parse(response.body)["access_token"]
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "[AvitoApi::Auth] token error #{e.http_code}: #{e.http_body}"
      nil
    rescue JSON::ParserError, StandardError => e
      Rails.logger.error "[AvitoApi::Auth] #{e.class}: #{e.message}"
      nil
    end
  end
end
