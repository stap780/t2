# frozen_string_literal: true

module MoyskladApi
  module Orders
    # Upsert заказа в реестре по данным customerorder из МойСклад.
    class SyncFromWebhook
      def self.call(moysklad:, order_json:, action:)
        new(moysklad:, order_json:, action:).call
      end

      def initialize(moysklad:, order_json:, action:)
        @moysklad = moysklad
        @order_json = order_json
        @action = action.to_s.upcase
      end

      def call
        order = find_or_initialize_order
        assign_order_attributes(order)
        order.save!

        sync_order_items(order)
        status_changed = apply_status(order)
        push_avito_status(order) if status_changed

        ReserveStock.call(@order_json, @moysklad) if @action == "CREATE"

        order
      end

      private

      def moysklad_order_uuid
        @moysklad_order_uuid ||= extract_uuid(@order_json.dig("meta", "href"))
      end

      def external_code
        @order_json["externalCode"].presence
      end

      def find_or_initialize_order
        order = Order.find_by(moysklad_order_id: moysklad_order_uuid) if moysklad_order_uuid.present?
        order ||= Order.find_by(moysklad_external_code: external_code) if external_code.present?
        order ||= Order.find_by(id: external_code) if external_code.to_s.match?(/\A\d+\z/)
        order ||= Order.new(source: "moysklad")

        order.moysklad_order_id = moysklad_order_uuid if moysklad_order_uuid.present?
        order
      end

      def assign_order_attributes(order)
        order.number = @order_json["name"].presence || order.number
        order.moysklad_external_code = external_code if external_code.present?
        order.comment = @order_json["description"].presence || order.comment
        order.total_sum = parse_sum(@order_json["sum"]) if @order_json.key?("sum")
        order.currency = "RUB"
        order.synced_at = Time.current
      end

      def sync_order_items(order)
        rows = @order_json.dig("positions", "rows") || []
        return if rows.empty?

        order.order_items.destroy_all

        rows.each do |row|
          variant = variant_for_row(row)
          order.order_items.create!(
            variant: variant,
            quantity: (row["quantity"] || 1).to_i,
            price: parse_sum(row["price"]),
            vat: row.dig("vat") || 0,
            title: row.dig("assortment", "name") || row["name"],
            sku: row.dig("assortment", "code")
          )
        end
      end

      def variant_for_row(row)
        href = row.dig("assortment", "meta", "href")
        return nil if href.blank?

        product_id = href.to_s.split("/").last
        return nil if product_id.blank?

        varbind = Varbind.find_by(bindable: @moysklad, value: product_id)
        record = varbind&.record
        record.is_a?(Variant) ? record : nil
      end

      def apply_status(order)
        state_href = @order_json.dig("state", "meta", "href")
        return false if state_href.blank?
        return false if order.last_moysklad_state_href == state_href

        mapping = MoyskladOrderStatusMapping.find_by(moysklad_state_href: state_href)
        attrs = { last_moysklad_state_href: state_href, synced_at: Time.current }
        attrs[:order_status_id] = mapping.order_status_id if mapping

        order.update!(attrs)
        true
      end

      def push_avito_status(order)
        result = AvitoApi::Orders::PushStatusFromOrder.call(order: order)
        return if result[:success] || result[:skipped]

        Rails.logger.warn(
          "[MoyskladApi::Orders::SyncFromWebhook] Avito status push failed " \
          "order=#{order.id}: #{result[:error]}"
        )
      end

      def parse_sum(value)
        return nil if value.nil?

        (value.to_f / 100).round(2)
      end

      def extract_uuid(href)
        return nil if href.blank?

        href.to_s.split("/").last.presence
      end
    end
  end
end
