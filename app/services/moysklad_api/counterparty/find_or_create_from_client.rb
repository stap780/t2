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
          return success_result(EntityHref.counterparty(varbind.value), client: @client)
        end

        href = find_by_email || create_counterparty
        return { success: false, error: "counterparty_not_created" } if href.blank?

        uuid = EntityHref.extract_id(href, entity: "counterparty")
        canonical = ::Client.find_by_external_id(bindable: @moysklad, value: uuid)
        return success_result(EntityHref.counterparty(uuid), client: canonical) if canonical

        save_varbind!(uuid)
        success_result(href, client: @client)
      rescue RestClient::ExceptionWithResponse => e
        body = e.response&.body
        Rails.logger.error "[MoyskladApi::Counterparty::FindOrCreateFromClient] #{e.response&.code}: #{body}"
        { success: false, error: "#{e.response&.code}: #{body}" }
      rescue StandardError => e
        Rails.logger.error "[MoyskladApi::Counterparty::FindOrCreateFromClient] #{e.class}: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def success_result(href, client:)
        { success: true, href: href, client: client }
      end

      def find_by_email
        return nil if @client.email.blank?
        return nil if ClientIdentity.avito_placeholder_email?(@client.email)

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
        payload["email"] = @client.email unless ClientIdentity.avito_placeholder_email?(@client.email)
        payload["phone"] = @client.phone if @client.phone.present?

        data = Client.post_json(@moysklad, "#{Api::API_BASE}/entity/counterparty", payload)
        data.dig("meta", "href")
      end

      def save_varbind!(uuid)
        return if uuid.blank?

        varbind = Varbind.find_or_initialize_by(record: @client, bindable: @moysklad)
        varbind.value = uuid
        varbind.save!
      end
    end
  end
end
