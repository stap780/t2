# frozen_string_literal: true

module Insales
  module Orders
    class PushStatusFromOrder
      def self.call(order:)
        PushFromOrder.call(order:)
      end
    end
  end
end
