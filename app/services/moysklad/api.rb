# frozen_string_literal: true

module Moysklad
  module Api
    API_BASE = "https://api.moysklad.ru/api/remap/1.2".freeze

    def self.basic_auth(moysklad)
      credentials = "#{moysklad.api_key}:#{moysklad.api_password}"
      "Basic #{Base64.strict_encode64(credentials)}"
    end

    def self.default_headers(auth_header)
      {
        Authorization: auth_header,
        Accept: "application/json;charset=utf-8"
      }
    end
  end
end
