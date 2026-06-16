# frozen_string_literal: true

# Значения полей заказа в реестре t2 по ключам OrderFieldSourceKeys (маппинги МС / InSales).
class OrderFieldValues
  def self.call(order:, source_key:)
    new(order:, source_key:).call
  end

  def initialize(order:, source_key:)
    @order = order
    @source_key = source_key
  end

  def call
    case @source_key
    when "order.number" then @order.number
    when "order.avito_marketplace_id" then @order.avito_marketplace_id
    when "order.tracking_number" then @order.tracking_number
    when "order.comment" then @order.comments_description
    when "order.total_sum" then @order.items_total
    when "client.name" then @order.client&.name
    when "client.email" then @order.client&.email
    when "client.phone" then @order.client&.phone
    when "integration.name" then OrderIntegrationName.call(@order)
    end
  end
end
