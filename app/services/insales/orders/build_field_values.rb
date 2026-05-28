# frozen_string_literal: true

module Insales
  module Orders
    class BuildFieldValues
      def self.call(order:)
        new(order:).call
      end

      def initialize(order:)
        @order = order
      end

      def call
        return [] unless @order.insale

        @order.insale.insales_order_field_mappings.filter_map do |mapping|
          value = OrderFieldValues.call(order: @order, source_key: mapping.source_key).to_s.presence
          next if value.blank?

          row = { "value" => value }
          row["field_id"] = mapping.insales_field_id if mapping.insales_field_id.present?
          row["handle"] = mapping.insales_field_handle if mapping.insales_field_handle.present?
          row
        end
      end
    end
  end
end
