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
        @messenger_profile_url = nil
      end

      def call
        avito_order_id = extract_avito_order_id
        return Result.new(skipped: true, error: "missing_avito_order_id") if avito_order_id.blank?

        existing = find_existing_order(avito_order_id)
        if OrdersIntegration::Cutover.skip?(
             known_in_app: existing.present?,
             source_created_at: @payload["createdAt"]
           )
          OrdersIntegration::Cutover.log_skip(source: "avito", identifier: avito_order_id)
          return Result.new(skipped: true)
        end

        order = existing || Order.new(source: "avito", avito_id: @avito.id)
        order.avito_order_id = avito_order_id
        created = order.new_record?

        order.source = "avito"
        order.avito_marketplace_id = extract_marketplace_id
        order.number = extract_number(order)
        order.tracking_number = extract_tracking_number if extract_tracking_number.present?
        order.total_sum = extract_total_sum
        order.order_status_id ||= default_order_status_id
        order.client ||= find_or_create_client
        order.synced_at = Time.current

        items = build_order_items
        return Result.new(order: order, skipped: true, error: "no_matched_items") if items.empty?

        order.save!
        order.order_items.destroy_all
        items.each { |attrs| order.order_items.create!(attrs) }
        attach_import_note(order)

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

      def extract_chat_id
        (@payload["items"] || []).find { |line| line["chatId"].present? }&.dig("chatId")
      end

      def extract_tracking_number
        delivery = @payload["delivery"]
        if delivery.is_a?(Hash)
          delivery["trackingNumber"].presence ||
            delivery["tracking_number"].presence ||
            delivery["dispatchNumber"].presence
        end ||
          @payload["trackingNumber"].presence ||
          @payload["tracking_number"].presence
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

      def build_import_note_body
        parts = []
        parts << "Авито: #{@avito.title}"
        parts << "Заказ #{extract_avito_order_id}"
        delivery = @payload["delivery"]
        if delivery.is_a?(Hash)
          parts << delivery["serviceName"] if delivery["serviceName"].present?
          addr = delivery.dig("terminalInfo", "address")
          parts << addr if addr.present?
        end
        buyer = from_buyer_info
        if buyer.present?
          parts << [buyer[:name], buyer[:phone]].compact.join(", ")
        end
        parts << "Avito профиль: #{@messenger_profile_url}" if @messenger_profile_url.present?
        parts.compact.join("\n")
      end

      def attach_import_note(order)
        body = build_import_note_body
        prefix = "Авито: #{@avito.title}\n"
        order.upsert_prefixed_note(body, prefix: prefix)
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
        AvitoApi::ProductLink.resolve_variant(avito: @avito, line: line)
      end

      def default_order_status_id
        OrderStatus.find_by(code: "new")&.id || OrderStatus.order(:position).first&.id
      end

      def find_or_create_client
        buyer = buyer_attributes_for_client
        if buyer.present?
          email = buyer[:email].presence || placeholder_email(buyer[:phone])
          phone = buyer[:phone].to_s.gsub(/\D/, "")
          name = buyer[:name].presence || @avito.title

          client = find_client_for_buyer(buyer, email: email, phone: phone)
          client ||= Client.create!(
            name: name,
            email: email,
            phone: phone.presence || "0",
            surname: buyer[:surname]
          )
          ensure_avito_varbind(client, buyer[:avito_user_id])
          return client
        end

        Client.find_or_create_by!(email: "avito-#{@avito.id}@#{@avito.api_id}.local") do |c|
          c.name = @avito.title
          c.phone = "0"
        end
      end

      def find_client_for_buyer(buyer, email:, phone:)
        if buyer[:avito_user_id].present?
          client = Client.find_by_external_id(bindable: @avito, value: buyer[:avito_user_id])
          return client if client
        end

        client = Client.find_by(email: email)
        client ||= Client.find_by(phone: phone) if phone.present?
        client
      end

      def ensure_avito_varbind(client, user_id)
        return if user_id.blank?

        existing = Varbind.find_by(bindable: @avito, value: user_id.to_s, record_type: "Client")
        return if existing&.record_id == client.id

        Varbind.find_or_create_by!(record: client, bindable: @avito) do |varbind|
          varbind.value = user_id.to_s
        end
      rescue ActiveRecord::RecordInvalid => e
        Rails.logger.warn "[AvitoApi::Orders::Import] avito varbind: #{e.message}"
      end


      def buyer_attributes_for_client
        from_buyer_info || from_messenger
      end

      def from_buyer_info
        info = @payload.dig("delivery", "buyerInfo")
        return unless info.is_a?(Hash) && buyer_data_present?(info)

        full_name = info["fullName"].to_s.strip
        surname, given_name = split_full_name(full_name)
        {
          name: given_name.presence || full_name,
          surname: surname,
          phone: info["phoneNumber"],
          email: info["email"]
        }
      end

      def from_messenger
        chat_id = extract_chat_id
        return if chat_id.blank?

        buyer = Messenger::FetchChat.call(avito: @avito, chat_id: chat_id)
        return unless buyer

        @messenger_profile_url = buyer[:profile_url]
        {
          name: buyer[:name],
          surname: nil,
          phone: nil,
          email: avito_user_email(buyer[:user_id]),
          avito_user_id: buyer[:user_id]
        }
      end

      def buyer_data_present?(hash)
        hash.values.any?(&:present?)
      end

      def split_full_name(full_name)
        parts = full_name.split(/\s+/, 2)
        parts.size >= 2 ? parts : [nil, full_name]
      end

      def avito_user_email(user_id)
        "avito-#{user_id}@placeholder.local"
      end

      def placeholder_email(phone)
        normalized_phone = phone.to_s.gsub(/\D/, "")
        if normalized_phone.present?
          "avito-#{normalized_phone}@placeholder.local"
        else
          "avito-#{extract_avito_order_id}@placeholder.local"
        end
      end
    end
  end
end
