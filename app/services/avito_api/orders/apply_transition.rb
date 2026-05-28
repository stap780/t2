# frozen_string_literal: true

require "rest-client"

module AvitoApi
  module Orders
    # Смена статуса заказа в Авито: POST /order-management/1/order/applyTransition
    # Документация: https://developers.avito.ru/api-catalog/order-management/documentation
    #
    # transition: confirm | reject | perform | receive
    class ApplyTransition
      PATH = "/order-management/1/order/applyTransition".freeze
      ALLOWED_TRANSITIONS = AvitoOrderStatusMapping::TRANSITIONS

      def self.call(order:)
        new(order:).call
      end

      def initialize(order:)
        @order = order
      end

      def call
        return { success: false, skipped: true, error: "not_avito_order" } unless @order.avito_channel?

        avito = @order.avito
        return { success: false, error: "avito_account_missing" } unless avito

        mapping = avito.avito_order_status_mappings.find_by(order_status_id: @order.order_status_id)
        return { success: false, skipped: true, error: "no_avito_status_mapping" } unless mapping

        transition = mapping.avito_status.to_s
        unless ALLOWED_TRANSITIONS.include?(transition)
          return { success: false, error: "invalid_transition" }
        end

        return { success: true, skipped: true, error: "already_sent" } if @order.avito_status_sent == transition

        order_id = @order.avito_order_id
        return { success: false, error: "avito_order_id_missing" } if order_id.blank?

        token = AvitoApi::Auth.access_token(avito)
        return { success: false, error: "no_avito_token" } if token.blank?

        payload = { orderId: order_id, transition: transition }
        response = RestClient.post(
          "#{AvitoApi::Auth::API_BASE}#{PATH}",
          payload.to_json,
          {
            Authorization: "Bearer #{token}",
            "Content-Type" => "application/json"
          }
        )
        body = JSON.parse(response.body)
        success = body["success"] != false

        if success
          @order.update!(avito_status_sent: transition, synced_at: Time.current)
          { success: true, transition: transition }
        else
          { success: false, error: "avito_rejected_transition", response: body }
        end
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "[AvitoApi::Orders::ApplyTransition] #{e.http_code}: #{e.http_body}"
        { success: false, error: "#{e.http_code}: #{e.http_body}" }
      rescue JSON::ParserError, StandardError => e
        Rails.logger.error "[AvitoApi::Orders::ApplyTransition] #{e.class}: #{e.message}"
        { success: false, error: e.message }
      end
    end
  end
end
