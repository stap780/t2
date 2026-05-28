# frozen_string_literal: true

require "rest-client"

module MoyskladApi
  class CustomerOrder
    # Fetch customerorder with positions by href
    # Returns order JSON or nil
    def self.fetch(moysklad, href)
      url = "#{href}?expand=positions,state"
      auth = Api.basic_auth(moysklad)
      headers = Api.default_headers(auth)
      response = RestClient.get(url, headers)
      JSON.parse(response.body)
    rescue RestClient::ExceptionWithResponse
      nil
    end
  end
end
