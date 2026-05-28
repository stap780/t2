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
        if OrdersIntegration::Cutover.skip?(
             known_in_app: order.persisted?,
             source_created_at: @payload["created_at"]
           )
          OrdersIntegration::Cutover.log_skip(source: "insales", identifier: insales_order_id)
          return Result.new(skipped: true)
        end

        created = order.new_record?

        order.source = "insales"
        order.insale = @insale
        order.number = extract_number(order)
        order.tracking_number = extract_tracking_number if extract_tracking_number.present?
        order.total_sum = extract_total_sum
        order.currency = extract_currency
        apply_status(order)
        order.client ||= find_or_create_client
        order.synced_at = Time.current

        rows = order_line_rows
        return Result.new(order: order, skipped: true, error: "empty_order_lines") if rows.empty?

        items = build_order_items(rows)
        if items.empty?
          return Result.new(
            order: order,
            skipped: true,
            error: "no_matched_items: #{unmatched_lines_summary(rows)}"
          )
        end

        order.save!
        order.order_items.destroy_all
        items.each { |attrs| order.order_items.create!(attrs) }
        attach_import_note(order)

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

      def extract_tracking_number
        @payload["delivery_tracking_number"].presence ||
          @payload["track_number"].presence ||
          @payload.dig("delivery_info", "tracking_number").presence ||
          @payload.dig("delivery_info", "track_number").presence
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
        mapping = find_status_mapping
        order.order_status_id = mapping.order_status_id if mapping
        order.order_status_id ||= default_order_status_id
      end

      def default_order_status_id
        OrderStatus.find_by(code: "new")&.id || OrderStatus.order(:position).first&.id
      end

      def find_status_mapping
        permalink = @payload.dig("custom_status", "permalink").presence
        financial_status = @payload["financial_status"].presence
        return nil if permalink.blank? || financial_status.blank?

        InsalesOrderStatusMapping.find_by(
          insale_id: @insale.id,
          insales_custom_status_permalink: permalink,
          insales_financial_status: financial_status
        )
      end

      def build_import_note_body(order)
        parts = []
        parts << "InSales: #{@insale.api_link}"
        parts << "Заказ ##{extract_number(order)} (id #{extract_insales_order_id})"
        parts << @payload["comment"] if @payload["comment"].present?
        parts << @payload["delivery_title"] if @payload["delivery_title"].present?
        addr = @payload.dig("shipping_address", "full_delivery_address")
        parts << addr if addr.present?
        parts.compact.join("\n")
      end

      def attach_import_note(order)
        body = build_import_note_body(order)
        prefix = "InSales: #{@insale.api_link}\n"
        order.upsert_prefixed_note(body, prefix: prefix)
      end

      def order_line_rows
        (@payload["order_lines"] || []).filter_map { |line| normalize_order_line(line) }
      end

      def normalize_order_line(line)
        return nil unless line.is_a?(Hash)

        line = line.stringify_keys
        nested = line["order_line"]
        line = nested.stringify_keys if nested.is_a?(Hash)
        line.presence
      end

      def build_order_items(rows)
        rows.filter_map do |line|
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

      def unmatched_lines_summary(rows)
        rows.map do |line|
          parts = []
          parts << "variant_id=#{line['variant_id']}" if line["variant_id"].present?
          parts << "sku=#{line['sku']}" if line["sku"].present?
          parts << "barcode=#{line['barcode']}" if line["barcode"].present?
          parts.join(", ").presence || "line"
        end.join("; ")
      end

      def variant_for_line(line)
        variant_id = line["variant_id"]
        if variant_id.present?
          varbind = Varbind.find_by(bindable: @insale, value: variant_id.to_s)
          record = varbind&.record
          return record if record.is_a?(Variant)
        end

        sku = line["sku"].presence
        variant = Variant.find_by(sku: sku) if sku.present?
        return variant if variant

        # InSales часто кладёт штрихкод в sku; varbind-sync тоже матчит по barcode
        barcode = line["barcode"].presence || sku
        Variant.find_by(barcode: barcode) if barcode.present?
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
