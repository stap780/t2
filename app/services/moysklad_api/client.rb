# frozen_string_literal: true

require "rest-client"

module MoyskladApi
  class Client
    def self.get_json(moysklad, url)
      response = RestClient.get(
        url,
        Api.default_headers(Api.basic_auth(moysklad))
      )
      JSON.parse(response.body)
    end

    def self.post_json(moysklad, url, payload)
      response = RestClient.post(
        url,
        payload.to_json,
        Api.default_headers(Api.basic_auth(moysklad)).merge(
          Content_Type: "application/json;charset=utf-8"
        )
      )
      JSON.parse(response.body)
    end
  end
end
