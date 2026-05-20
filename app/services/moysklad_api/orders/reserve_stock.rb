# frozen_string_literal: true

module MoyskladApi
  module Orders
    # Списание остатков по резерву позиций заказа МС (как в прежнем Api::MoyskladsController).
    class ReserveStock
      def self.call(order_json, moysklad)
        new(order_json, moysklad).call
      end

      def initialize(order_json, moysklad)
        @order_json = order_json
        @moysklad = moysklad
      end

      def call
        rows = @order_json.dig("positions", "rows") || []
        rows.each { |row| process_row(row) }
      end

      private

      def process_row(row)
        href = row.dig("assortment", "meta", "href")
        return if href.blank?

        product_id = href.to_s.split("/").last
        return if product_id.blank?

        varbind = Varbind.find_by(bindable: @moysklad, value: product_id)
        return unless varbind

        variant = varbind.record
        return unless variant.is_a?(Variant)

        reserve = (row["reserve"] || 0).to_i
        return if reserve <= 0

        new_quantity = [variant.quantity - reserve, 0].max
        variant.update!(quantity: new_quantity)
      rescue StandardError => e
        Rails.logger.error "[MoyskladApi::Orders::ReserveStock] #{e.message}"
      end
    end
  end
end
