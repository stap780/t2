# frozen_string_literal: true

module MoyskladApi
  module Counterparty
    # Контрагент (agent) из customerorder МойСклад → Client в t2 + Varbind.
    class SyncToClient
      PLACEHOLDER_EMAIL_DOMAIN = "moysklad.local"

      def self.call(moysklad:, order_json:)
        new(moysklad:, order_json:).call
      end

      def initialize(moysklad:, order_json:)
        @moysklad = moysklad
        @order_json = order_json
      end

      def call
        data = counterparty_attributes
        return nil unless data

        client = find_client(data) || create_client(data)
        update_client!(client, data)
        ensure_varbind!(client, data[:uuid])
        client
      rescue StandardError => e
        Rails.logger.error "[MoyskladApi::Counterparty::SyncToClient] #{e.class}: #{e.message}"
        nil
      end

      private

      def counterparty_attributes
        agent = @order_json["agent"]
        return nil if agent.blank?

        uuid = EntityHref.extract_id(agent.dig("meta", "href"), entity: "counterparty")
        return nil if uuid.blank?

        source = agent_expanded?(agent) ? agent : fetch_counterparty(uuid)
        return nil if source.blank?

        {
          uuid: uuid,
          name: source["name"].to_s.presence,
          email: source["email"].to_s.presence,
          phone: source["phone"].to_s.presence
        }
      end

      def agent_expanded?(agent)
        agent.key?("name") || agent.key?("email") || agent.key?("phone")
      end

      def fetch_counterparty(uuid)
        MoyskladApi::Client.get_json(@moysklad, EntityHref.counterparty(uuid))
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error(
          "[MoyskladApi::Counterparty::SyncToClient] counterparty fetch " \
          "#{e.response&.code}: #{e.response&.body}"
        )
        nil
      end

      def find_client(data)
        ::Client.find_by_external_id(bindable: @moysklad, value: data[:uuid]) ||
          (data[:email].present? ? ::Client.find_by(email: data[:email]) : nil)
      end

      def create_client(data)
        ::Client.create!(
          name: data[:name].presence || "Клиент МС",
          email: data[:email].presence || placeholder_email(data[:uuid]),
          phone: normalize_phone(data[:phone]).presence || "0"
        )
      end

      def update_client!(client, data)
        attrs = {}
        attrs[:name] = data[:name] if data[:name].present?
        attrs[:phone] = normalize_phone(data[:phone]) if data[:phone].present?
        attrs[:email] = data[:email] if data[:email].present? && email_available?(data[:email], client)
        client.update!(attrs) if attrs.any?
      end

      def ensure_varbind!(client, uuid)
        varbind = Varbind.find_or_initialize_by(record: client, bindable: @moysklad)
        varbind.value = uuid
        varbind.save!
      end

      def email_available?(email, client)
        existing = ::Client.find_by(email: email)
        existing.nil? || existing.id == client.id
      end

      def placeholder_email(uuid)
        "ms-#{uuid}@#{PLACEHOLDER_EMAIL_DOMAIN}"
      end

      def normalize_phone(phone)
        phone.to_s.gsub(/\D/, "")
      end
    end
  end
end
