# frozen_string_literal: true

module Insales
  module Orders
    # Обработка вебхука orders/create или orders/update.
    class ProcessWebhook
      def self.call(insale:, payload:)
        new(insale:, payload:).call
      end

      def initialize(insale:, payload:)
        @insale = insale
        @payload = payload
        @moysklad = Moysklad.first
      end

      def call
        result = Import.call(insale: @insale, payload: @payload)
        if result.error.present?
          Rails.logger.warn "[Insales::Orders::ProcessWebhook] import error: #{result.error}"
          return result
        end
        if result.skipped
          Rails.logger.info "[Insales::Orders::ProcessWebhook] skipped: #{result.error}"
          return result
        end

        push_to_moysklad(result.order) if result.order
        result
      end

      private

      def push_to_moysklad(order)
        return unless @moysklad
        return if order.moysklad_order_id.present?

        ms_result = MoyskladApi::Orders::CreateFromAppOrder.call(order: order, moysklad: @moysklad)
        return if ms_result[:success]

        Rails.logger.warn(
          "[Insales::Orders::ProcessWebhook] MS export failed order=#{order.id}: #{ms_result[:error]}"
        )
      end
    end
  end
end
