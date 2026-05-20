# frozen_string_literal: true

require "rest-client"

module MoyskladApi
  class Webhook
    DEFAULT_URL = "https://cpt.dizauto.ru/api/moysklads/order".freeze
    ORDER_ACTIONS = %w[CREATE UPDATE].freeze

    # Add webhook for customerorder (CREATE or UPDATE)
    # Returns [true, message] or [false, [error_messages]]
    def self.add(moysklad:, url: nil, action: "CREATE")
      return [false, ["No Moysklad configuration"]] unless moysklad

      return [false, ["API not working"]] unless moysklad.api_work?[0]

      target_address = url || DEFAULT_URL
      action = action.to_s.upcase

      begin
        token = fetch_access_token(moysklad)
        return [false, ["Failed to get access token"]] if token.blank?

        webhooks = list_webhooks(token)
        existing = webhooks.find do |w|
          w["url"] == target_address &&
            w["entityType"] == "customerorder" &&
            w["action"] == action
        end
        if existing
          return [true, "Webhook #{action} already exists. OK"]
        end

        create_webhook(token, target_address, action)
        [true, "Webhook #{action} created successfully"]
      rescue RestClient::ExceptionWithResponse => e
        [false, ["MoySklad API error: #{e.response.code} #{e.response.body}"]]
      rescue StandardError => e
        [false, ["Error creating webhook: #{e.message}"]]
      end
    end

    # CREATE + UPDATE для заказов покупателя
    def self.add_order_webhooks(moysklad:, url: nil)
      messages = []
      ok = true

      ORDER_ACTIONS.each do |action|
        success, result = add(moysklad: moysklad, url: url, action: action)
        ok &&= success
        messages << (result.is_a?(Array) ? result.join(", ") : result.to_s)
      end

      [ok, messages]
    end

    def self.fetch_access_token(moysklad)
      url = "#{Api::API_BASE}/security/token"
      auth = Api.basic_auth(moysklad)
      response = RestClient.post(url, {}, Api.default_headers(auth).merge(Content_Type: "application/json"))
      JSON.parse(response.body)["access_token"]
    rescue RestClient::ExceptionWithResponse
      nil
    end

    def self.list_webhooks(token)
      url = "#{Api::API_BASE}/entity/webhook"
      headers = Api.default_headers("Bearer #{token}")
      response = RestClient.get(url, headers)
      body = JSON.parse(response.body)
      body["rows"] || []
    rescue RestClient::ExceptionWithResponse
      []
    end

    def self.create_webhook(token, url, action)
      api_url = "#{Api::API_BASE}/entity/webhook"
      headers = Api.default_headers("Bearer #{token}").merge(
        Content_Type: "application/json"
      )
      payload = { url: url, action: action, entityType: "customerorder" }.to_json
      response = RestClient.post(api_url, payload, headers)
      JSON.parse(response.body)
    end
  end
end
