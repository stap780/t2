# frozen_string_literal: true

require "cgi"

module MoyskladApi
  module Counterparty
    class FindOrCreateFromClient
      def self.call(moysklad:, client:)
        new(moysklad:, client:).call
      end

      def initialize(moysklad:, client:)
        @moysklad = moysklad
        @client = client
      end

      def call
        return { success: false, error: "no_client" } unless @client

        varbind = Varbind.find_by(record: @client, bindable: @moysklad)
        if varbind&.value.present?
          return { success: true, href: EntityHref.counterparty(varbind.value) }
        end

        href = find_by_email || create_counterparty
        return { success: false, error: "counterparty_not_created" } if href.blank?

        uuid = EntityHref.extract_id(href, entity: "counterparty")
        save_varbind!(uuid)
        { success: true, href: href }
      rescue RestClient::ExceptionWithResponse => e
        body = e.response&.body
        Rails.logger.error "[MoyskladApi::Counterparty::FindOrCreateFromClient] #{e.response&.code}: #{body}"
        { success: false, error: "#{e.response&.code}: #{body}" }
      rescue StandardError => e
        Rails.logger.error "[MoyskladApi::Counterparty::FindOrCreateFromClient] #{e.class}: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def find_by_email
        return nil if @client.email.blank?

        filter = CGI.escape("email=#{@client.email}")
        data = Client.get_json(
          @moysklad,
          "#{Api::API_BASE}/entity/counterparty?filter=#{filter}&limit=1"
        )
        data.dig("rows", 0, "meta", "href")
      end

      def create_counterparty
        name = @client.name.presence || @client.email.presence || "Клиент ##{@client.id}"
        payload = { "name" => name }
        payload["email"] = @client.email if @client.email.present?
        payload["phone"] = @client.phone if @client.phone.present?

        data = Client.post_json(@moysklad, "#{Api::API_BASE}/entity/counterparty", payload)
        data.dig("meta", "href")
      end

      def save_varbind!(uuid)
        return if uuid.blank?

        Varbind.find_or_create_by!(record: @client, bindable: @moysklad) do |varbind|
          varbind.value = uuid
        end
      end
    end
  end
end
