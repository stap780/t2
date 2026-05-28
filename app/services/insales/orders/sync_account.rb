# frozen_string_literal: true

module Insales
  module Orders
    class SyncAccount
      Stats = Struct.new(:imported, :updated, :skipped, :moysklad_created, :errors, keyword_init: true)

      def self.call(insale:, params: {})
        new(insale:, params:).call
      end

      def initialize(insale:, params: {})
        @insale = insale
        @params = params
        @stats = Stats.new(imported: 0, updated: 0, skipped: 0, moysklad_created: 0, errors: [])
      end

      def call
        unless api_works?
          @stats.errors << "api_not_working"
          return @stats
        end

        orders_payload = List.call(insale: @insale, params: @params)
        orders_payload = orders_payload.first(1) if Rails.env.development?
        orders_payload.each { |payload| process_one(payload) }
        @stats
      end

      private

      def api_works?
        ok, = @insale.api_work?
        ok
      end

      def process_one(payload)
        insales_order_id = payload["id"].presence&.to_s
        had_ms = insales_order_id.present? &&
                 Order.find_by(insale_id: @insale.id, insales_order_id: insales_order_id)&.moysklad_order_id.present?

        result = ProcessWebhook.call(insale: @insale, payload: payload)
        if result.error.present?
          @stats.errors << result.error
          @stats.skipped += 1
          return
        end
        if result.skipped
          @stats.skipped += 1
          @stats.errors << result.error if result.error.present?
          return
        end

        if result.created
          @stats.imported += 1
        else
          @stats.updated += 1
        end

        return unless result.order && !had_ms && result.order.moysklad_order_id.present?

        @stats.moysklad_created += 1
      end
    end
  end
end
