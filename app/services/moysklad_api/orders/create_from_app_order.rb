# frozen_string_literal: true

require "rest-client"

module MoyskladApi
  module Orders
    # Создание customerorder в МойСклад из записи Order (Avito / InSales).
    class CreateFromAppOrder
      def self.call(order:, moysklad:)
        new(order:, moysklad:).call
      end

      def initialize(order:, moysklad:)
        @order = order
        @moysklad = moysklad
      end

      def call
        return { success: false, error: "already_exported" } if @order.moysklad_order_id.present?

        positions = build_positions
        return { success: false, error: "no_moysklad_positions" } if positions.empty?

        org_href = @moysklad.organization_href
        return { success: false, error: "moysklad_not_configured" } if org_href.blank?

        return { success: false, error: "no_client_for_agent" } unless @order.client

        agent_result = Counterparty::FindOrCreateFromClient.call(moysklad: @moysklad, client: @order.client)
        return agent_result unless agent_result[:success]

        if @moysklad.default_ad_source_href.blank?
          return { success: false, error: "default_ad_source_not_configured" }
        end

        payload = {
          "externalCode" => @order.id.to_s,
          "description" => @order.comments_description.truncate(4000),
          "organization" => meta(org_href),
          "agent" => meta(agent_result[:href]),
          "positions" => positions
        }
        name = order_name
        payload["name"] = name if name.present?
        payload["store"] = meta(@moysklad.store_href) if @moysklad.store_href.present?

        attributes = BuildCustomAttributes.call(order: @order, moysklad: @moysklad)
        payload["attributes"] = attributes if attributes.any?

        response = RestClient.post(
          "#{Api::API_BASE}/entity/customerorder",
          payload.to_json,
          Api.default_headers(Api.basic_auth(@moysklad)).merge(
            Content_Type: "application/json;charset=utf-8"
          )
        )
        data = JSON.parse(response.body)
        uuid = data.dig("meta", "href").to_s.split("/").last

        @order.update!(
          moysklad_order_id: uuid,
          moysklad_external_code: @order.id.to_s,
          synced_at: Time.current
        )

        { success: true, moysklad_order_id: uuid }
      rescue RestClient::ExceptionWithResponse => e
        body = e.response&.body
        Rails.logger.error "[MoyskladApi::Orders::CreateFromAppOrder] #{e.response&.code}: #{body}"
        { success: false, error: "#{e.response&.code}: #{body}" }
      rescue StandardError => e
        Rails.logger.error "[MoyskladApi::Orders::CreateFromAppOrder] #{e.class}: #{e.message}"
        { success: false, error: e.message }
      end

      private

      def order_name
        prefix = @moysklad.order_number_prefix.to_s.strip
        prefix.present? ? prefix : ""
      end

      def build_positions
        @order.order_items.includes(variant: :bindings).filter_map do |item|
          next unless item.variant

          moy_bind = item.variant.bindings.find_by(bindable: @moysklad)
          next unless moy_bind&.value.present?

          {
            "quantity" => item.quantity,
            "price" => ((item.price || 0) * 100).round(0),
            "assortment" => {
              "meta" => {
                "href" => "#{Api::API_BASE}/entity/product/#{moy_bind.value}",
                "type" => "product",
                "mediaType" => "application/json"
              }
            }
          }
        end
      end

      def meta(href)
        {
          "meta" => {
            "href" => href,
            "type" => entity_type_for_href(href),
            "mediaType" => "application/json"
          }
        }
      end

      def entity_type_for_href(href)
        case href.to_s
        when %r{/organization/} then "organization"
        when %r{/counterparty/} then "counterparty"
        when %r{/store/} then "store"
        else "product"
        end
      end
    end
  end
end
