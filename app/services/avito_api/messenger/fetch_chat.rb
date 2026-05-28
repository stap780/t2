# frozen_string_literal: true

require "rest-client"

module AvitoApi
  module Messenger
    class FetchChat
      def self.call(avito:, chat_id:)
        new(avito:, chat_id:).call
      end

      def initialize(avito:, chat_id:)
        @avito = avito
        @chat_id = chat_id.to_s.strip
      end

      def call
        return if @chat_id.blank? || @avito.profileid.blank?

        token = AvitoApi::Auth.access_token(@avito)
        return if token.blank?

        uid = @avito.profileid
        url = "#{AvitoApi::Auth::API_BASE}/messenger/v2/accounts/#{uid}/chats/#{@chat_id}"
        response = RestClient.get(url, { Authorization: "Bearer #{token}" })
        body = JSON.parse(response.body)
        buyer = find_buyer(body["users"] || [])
        return unless buyer

        {
          user_id: buyer["id"].to_s,
          name: buyer["name"].to_s.presence,
          profile_url: buyer.dig("public_user_profile", "url").to_s.presence
        }
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "[AvitoApi::Messenger::FetchChat] #{e.http_code}: #{e.http_body}"
        nil
      rescue JSON::ParserError, StandardError => e
        Rails.logger.error "[AvitoApi::Messenger::FetchChat] #{e.class}: #{e.message}"
        nil
      end

      private

      def find_buyer(users)
        seller_id = @avito.profileid.to_i
        users.find { |user| user["id"].to_i != seller_id }
      end
    end
  end
end
