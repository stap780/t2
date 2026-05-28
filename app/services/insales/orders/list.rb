# frozen_string_literal: true

module Insales
  module Orders
    class List
      DEFAULT_PER_PAGE = 100

      def self.call(insale:, params: {})
        new(insale:, params:).call
      end

      def initialize(insale:, params: {})
        @insale = insale
        @params = params
      end

      def call
        @insale.api_init
        query = { per_page: DEFAULT_PER_PAGE, page: 1 }.merge(@params.compact)
        orders = InsalesApi::Order.all(params: query)
        Array(orders).map { |order| order_payload(order) }
      rescue StandardError => e
        Rails.logger.error "[Insales::Orders::List] #{e.class}: #{e.message}"
        []
      end

      private

      def order_payload(order)
        data = order.is_a?(Hash) ? order : JSON.parse(order.to_json)
        data.stringify_keys
      end
    end
  end
end
