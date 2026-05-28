# frozen_string_literal: true

module MoyskladApi
  module Orders
    # Pull customerorder from МойСклад and apply SyncFromWebhook (manual dev / без webhook).
    class SyncFromMoysklad
      def self.call(order:, moysklad:)
        new(order:, moysklad:).call
      end

      def initialize(order:, moysklad:)
        @order = order
        @moysklad = moysklad
      end

      def call
        return { success: false, error: "not_linked_to_moysklad" } unless @order.moysklad_order_id.present?

        href = "#{Api::API_BASE}/entity/customerorder/#{@order.moysklad_order_id}"
        order_json = MoyskladApi::CustomerOrder.fetch(@moysklad, href)
        return { success: false, error: "moysklad_order_not_found" } unless order_json

        SyncFromWebhook.call(moysklad: @moysklad, order_json: order_json, action: "UPDATE")
        { success: true }
      rescue StandardError => e
        Rails.logger.error "[MoyskladApi::Orders::SyncFromMoysklad] #{e.class}: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
