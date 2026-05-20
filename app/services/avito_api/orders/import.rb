# frozen_string_literal: true

module AvitoApi
  module Orders
    # Импорт одного заказа Авито в реестр Order + OrderItem.
    class Import
      Result = Struct.new(:order, :created, :skipped, :error, keyword_init: true)

      def self.call(avito:, payload:)
        new(avito:, payload:).call
      end

      def initialize(avito:, payload:)
        @avito = avito
        @payload = payload
      end

      def call
        avito_order_id = extract_avito_order_id
        return Result.new(skipped: true, error: "missing_avito_order_id") if avito_order_id.blank?

        order = find_existing_order(avito_order_id) || Order.new(source: "avito", avito_id: @avito.id)
        order.avito_order_id = avito_order_id
        created = order.new_record?

        order.source = "avito"
        order.avito_marketplace_id = extract_marketplace_id if extract_marketplace_id.present?
        order.number = extract_number(order)
        order.total_sum = extract_total_sum
        order.comment = build_comment(order)
        order.order_status_id ||= default_order_status_id
        order.client ||= find_or_create_client
        order.synced_at = Time.current

        items = build_order_items
        return Result.new(order: order, skipped: true, error: "no_matched_items") if items.empty?

        order.save!
        order.order_items.destroy_all
        items.each { |attrs| order.order_items.create!(attrs) }

        Result.new(order: order, created: created)
      rescue StandardError => e
        Rails.logger.error "[AvitoApi::Orders::Import] #{e.class}: #{e.message}"
        Result.new(error: e.message)
      end

      private

      # ID для API applyTransition (поле id в ответе списка заказов)
      def find_existing_order(avito_order_id)
        order = Order.find_by(avito_id: @avito.id, avito_order_id: avito_order_id)
        mp = extract_marketplace_id
        order || (mp.present? ? Order.find_by(avito_id: @avito.id, avito_marketplace_id: mp) : nil)
      end

      def extract_avito_order_id
        @payload["id"].presence || @payload["orderId"].presence
      end

      def extract_marketplace_id
        @payload["marketplaceId"].presence
      end

      def extract_number(order)
        extract_marketplace_id ||
          extract_avito_order_id ||
          order.number
      end

      def extract_total_sum
        total = @payload.dig("prices", "total") ||
                @payload.dig("prices", "totalPrice") ||
                @payload["total"]
        return nil if total.nil?

        total.is_a?(Hash) ? total["value"]&.to_f : total.to_f
      end

      def build_comment(order)
        parts = []
        parts << "Авито: #{@avito.title}"
        parts << "Заказ #{extract_avito_order_id}"
        delivery = @payload["delivery"]
        if delivery.is_a?(Hash)
          parts << delivery["serviceName"] if delivery["serviceName"].present?
          addr = delivery.dig("terminalInfo", "address")
          parts << addr if addr.present?
        end
        buyer = @payload["buyer"]
        if buyer.is_a?(Hash)
          parts << [buyer["name"], buyer["phone"]].compact.join(", ")
        end
        parts << order.comment if order.comment.present?
        parts.compact.join("\n")
      end

      def build_order_items
        rows = @payload["items"] || []
        rows.filter_map do |line|
          variant = variant_for_line(line)
          next unless variant

          price = line.dig("prices", "price") || line["price"]
          qty = (line["count"] || line["quantity"] || 1).to_i
          {
            variant: variant,
            quantity: qty,
            price: price.to_f,
            title: line["title"] || variant.product&.title,
            sku: variant.sku
          }
        end
      end

      def variant_for_line(line)
        item_id = line["id"] || line["itemId"] || line["listingId"]
        return nil if item_id.blank?

        varbind = Varbind.find_by(bindable: @avito, value: item_id.to_s)
        record = varbind&.record
        record.is_a?(Variant) ? record : nil
      end

      def default_order_status_id
        OrderStatus.find_by(code: "new")&.id || OrderStatus.order(:position).first&.id
      end

      def find_or_create_client
        buyer = @payload["buyer"] if @payload["buyer"].is_a?(Hash)
        if buyer.present?
          email = buyer["email"].presence || "avito-#{extract_avito_order_id}@placeholder.local"
          phone = buyer["phone"].to_s.gsub(/\D/, "")
          name = buyer["name"].presence || @avito.title
          client = Client.find_by(email: email)
          client ||= Client.create!(
            name: name,
            email: email,
            phone: phone.presence || "0",
            surname: buyer["surname"]
          )
          return client
        end

        Client.find_or_create_by!(email: "avito-#{@avito.id}@#{@avito.api_id}.local") do |c|
          c.name = @avito.title
          c.phone = "0"
        end
      end
    end
  end
end
