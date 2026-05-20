# frozen_string_literal: true

module AvitoApi
  module Orders
    class SyncAccount
      Stats = Struct.new(:imported, :updated, :skipped, :moysklad_created, :errors, keyword_init: true)

      def self.call(avito:, params: {})
        new(avito:, params:).call
      end

      def initialize(avito:, params: {})
        @avito = avito
        @params = params
        @moysklad = Moysklad.first
        @stats = Stats.new(imported: 0, updated: 0, skipped: 0, moysklad_created: 0, errors: [])
      end

      def call
        if AvitoApi::Auth.access_token(@avito).blank?
          @stats.errors << "no_avito_token"
          return @stats
        end

        orders_payload = List.call(avito: @avito, params: @params)
        orders_payload.each { |payload| process_one(payload) }
        @stats
      end

      private

      def process_one(payload)
        result = Import.call(avito: @avito, payload: payload)
        if result.error.present?
          @stats.errors << result.error
          @stats.skipped += 1
          return
        end

        if result.skipped
          @stats.skipped += 1
          return
        end

        if result.created
          @stats.imported += 1
        else
          @stats.updated += 1
        end

        push_to_moysklad(result.order)
      end

      def push_to_moysklad(order)
        return unless @moysklad
        return if order.moysklad_order_id.present?

        ms_result = MoyskladApi::Orders::CreateFromAppOrder.call(order: order, moysklad: @moysklad)
        if ms_result[:success]
          @stats.moysklad_created += 1
        elsif ms_result[:error].present?
          @stats.errors << "MS order ##{order.id}: #{ms_result[:error]}"
        end
      end
    end
  end
end
