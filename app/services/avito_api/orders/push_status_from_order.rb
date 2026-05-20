# frozen_string_literal: true

module AvitoApi
  module Orders
    # После обновления внутреннего статуса — отправить transition в Авито (этап D).
    class PushStatusFromOrder
      def self.call(order:)
        new(order:).call
      end

      def initialize(order:)
        @order = order
      end

      def call
        ApplyTransition.call(order: @order)
      end
    end
  end
end
