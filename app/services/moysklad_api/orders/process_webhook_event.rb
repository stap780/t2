# frozen_string_literal: true

module MoyskladApi
  module Orders
    class ProcessWebhookEvent
      def self.call(moysklad:, event:)
        new(moysklad:, event:).call
      end

      def initialize(moysklad:, event:)
        @moysklad = moysklad
        @event = event
      end

      def call
        return unless customerorder_event?

        href = @event.dig("meta", "href")
        return if href.blank?

        order_json = MoyskladApi::Order.fetch(@moysklad, href)
        return unless order_json

        action = @event["action"].presence || "CREATE"
        SyncFromWebhook.call(moysklad: @moysklad, order_json: order_json, action: action)
      end

      private

      def customerorder_event?
        @event.dig("meta", "type") == "customerorder"
      end
    end
  end
end
