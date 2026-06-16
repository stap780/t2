# frozen_string_literal: true

class OrderIntegrationName
  def self.call(order)
    new(order).call
  end

  def initialize(order)
    @order = order
  end

  def call
    if @order.avito
      @order.avito.title
    elsif @order.insale
      @order.insale.title.presence || @order.insale.api_link
    elsif @order.source == "moysklad"
      Moysklad.first&.title
    end
  end
end
