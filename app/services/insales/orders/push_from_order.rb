# frozen_string_literal: true

require "rest-client"

module Insales
  module Orders
    # Обратная синхронизация в InSales: статус + доп. поля заказа (после изменений в МС / вручную).
    class PushFromOrder
      def self.call(order:)
        new(order:).call
      end

      def initialize(order:)
        @order = order
      end

      def call
        return { success: false, skipped: true, error: "not_insales_order" } unless @order.insales_channel?

        insale = @order.insale
        return { success: false, error: "insale_missing" } unless insale

        insales_order_id = @order.insales_order_id
        return { success: false, error: "insales_order_id_missing" } if insales_order_id.blank?

        payload = build_payload
        return { success: true, skipped: true, error: "nothing_to_push" } if payload.empty?

        insale.api_init
        RestClient.put(
          order_url(insale, insales_order_id),
          { order: payload }.to_json,
          {
            content_type: :json,
            accept: :json,
            Authorization: basic_auth(insale)
          }
        )

        { success: true, payload_keys: payload.keys }
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "[Insales::Orders::PushFromOrder] #{e.http_code}: #{e.http_body}"
        { success: false, error: "#{e.http_code}: #{e.http_body}" }
      rescue StandardError => e
        Rails.logger.error "[Insales::Orders::PushFromOrder] #{e.class}: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def build_payload
        payload = {}
        status_mapping = find_status_mapping
        if status_mapping
          payload["custom_status_permalink"] = status_mapping.insales_custom_status_permalink
          payload["financial_status"] = status_mapping.insales_financial_status if status_mapping.insales_financial_status.present?
        end

        field_values = BuildFieldValues.call(order: @order)
        payload["fields_values_attributes"] = field_values if field_values.any?
        payload
      end

      def find_status_mapping
        return nil unless @order.order_status_id.present?

        InsalesOrderStatusMapping.find_by(
          insale_id: @order.insale_id,
          order_status_id: @order.order_status_id
        )
      end

      def order_url(insale, insales_order_id)
        host = insale.api_link.to_s.sub(%r{\Ahttps?://}, "")
        "https://#{host}/admin/orders/#{insales_order_id}.json"
      end

      def basic_auth(insale)
        credentials = Base64.strict_encode64("#{insale.api_key}:#{insale.api_password}")
        "Basic #{credentials}"
      end
    end
  end
end
