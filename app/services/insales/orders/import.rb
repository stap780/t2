# frozen_string_literal: true

module Insales
  module Orders
    # Импорт одного заказа InSales в реестр Order + OrderItem.
    # Payload — JSON заказа (GET /admin/orders/:id.json, вебхук orders/create|update).
    class Import
      Result = Struct.new(:order, :created, :skipped, :error, keyword_init: true)

      def self.call(insale:, payload:)
        new(insale:, payload:).call
      end

      def initialize(insale:, payload:)
        @insale = insale
        @payload = payload.is_a?(Hash) ? payload.stringify_keys : {}
      end

      def call
        insales_order_id = extract_insales_order_id
        return Result.new(skipped: true, error: "missing_insales_order_id") if insales_order_id.blank?

        order = Order.find_or_initialize_by(insale_id: @insale.id, insales_order_id: insales_order_id)
        created = order.new_record?

        order.source = "insales"
        order.insale = @insale
        order.number = extract_number(order)
        order.total_sum = extract_total_sum
        order.currency = extract_currency
        order.comment = build_comment(order)
        apply_status(order)
        order.client ||= find_or_create_client
        order.synced_at = Time.current

        items = build_order_items
        return Result.new(order: order, skipped: true, error: "no_matched_items") if items.empty?

        order.save!
        order.order_items.destroy_all
        items.each { |attrs| order.order_items.create!(attrs) }

        Result.new(order: order, created: created)
      rescue StandardError => e
        Rails.logger.error "[Insales::Orders::Import] #{e.class}: #{e.message}"
        Result.new(error: e.message)
      end

      private

      def extract_insales_order_id
        @payload["id"].presence&.to_s
      end

      def extract_number(order)
        @payload["number"].presence&.to_s || order.number
      end

      def extract_total_sum
        val = @payload["total_price"] || @payload["items_price"]
        val.nil? ? nil : val.to_f
      end

      def extract_currency
        code = @payload["currency_code"].presence || "RUB"
        code == "RUR" ? "RUB" : code
      end

      def apply_status(order)
        key = status_key
        mapping = key.present? ? find_status_mapping(key) : nil
        order.order_status_id = mapping.order_status_id if mapping
        order.order_status_id ||= default_order_status_id
      end

      def default_order_status_id
        OrderStatus.find_by(code: "new")&.id || OrderStatus.order(:position).first&.id
      end

      def status_key
        @payload.dig("custom_status", "permalink").presence ||
          @payload["fulfillment_status"].presence
      end

      def find_status_mapping(key)
        InsalesOrderStatusMapping
          .where(insales_status_key: key)
          .where(insale_id: [@insale.id, nil])
          .order(Arel.sql("CASE WHEN insale_id IS NULL THEN 1 ELSE 0 END"))
          .first
      end

      def build_comment(order)
        parts = []
        parts << "InSales: #{@insale.api_link}"
        parts << "Заказ ##{extract_number(order)} (id #{extract_insales_order_id})"
        parts << @payload["comment"] if @payload["comment"].present?
        parts << @payload["delivery_title"] if @payload["delivery_title"].present?
        addr = @payload.dig("shipping_address", "full_delivery_address")
        parts << addr if addr.present?
        parts << order.comment if order.comment.present?
        parts.compact.join("\n")
      end

      def build_order_items
        rows = @payload["order_lines"] || []
        rows.filter_map do |line|
          line = line.stringify_keys if line.is_a?(Hash)
          variant = variant_for_line(line)
          next unless variant

          price = line["full_sale_price"] || line["sale_price"] || line["full_total_price"]
          qty = (line["quantity"] || 1).to_i
          {
            variant: variant,
            quantity: qty,
            price: price.to_f,
            title: line["title"],
            sku: line["sku"]
          }
        end
      end

      def variant_for_line(line)
        variant_id = line["variant_id"]
        if variant_id.present?
          varbind = Varbind.find_by(bindable: @insale, value: variant_id.to_s)
          record = varbind&.record
          return record if record.is_a?(Variant)
        end

        sku = line["sku"].presence
        return nil if sku.blank?

        Variant.find_by(sku: sku)
      end

      def find_or_create_client
        client_data = @payload["client"]
        if client_data.is_a?(Hash)
          client_data = client_data.stringify_keys
          insid = client_data["id"]
          email = client_data["email"].presence || "insales-#{insid || extract_insales_order_id}@placeholder.local"
          phone = client_data["phone"].to_s.gsub(/\D/, "")
          name = client_data["name"].presence || "InSales клиент"
          client = Client.find_by(email: email)
          client ||= Client.create!(
            name: name,
            email: email,
            phone: phone.presence || "0",
            surname: client_data["surname"]
          )
          return client
        end

        Client.find_or_create_by!(email: "insales-shop-#{@insale.id}@local") do |c|
          c.name = @insale.api_link
          c.phone = "0"
        end
      end
    end
  end
end
