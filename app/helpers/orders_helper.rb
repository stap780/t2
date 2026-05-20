# frozen_string_literal: true

module OrdersHelper
  SOURCE_STYLES = {
    "avito" => "bg-orange-100 text-orange-800",
    "insales" => "bg-blue-100 text-blue-800",
    "moysklad" => "bg-emerald-100 text-emerald-800"
  }.freeze

  def order_source_badge(order)
    label = t("orders.sources.#{order.source}", default: order.source)
    css = SOURCE_STYLES[order.source] || "bg-gray-100 text-gray-800"
    tag.span(label, class: "inline-flex px-2 py-0.5 text-xs font-medium rounded-full #{css}")
  end

  def order_status_badge(order)
    return tag.span("—", class: "text-gray-400") unless order.order_status

    status = order.order_status
    style = status.color.present? ? "background-color: #{status.color}; color: #fff;" : ""
    tag.span(
      status.title,
      class: "inline-flex px-2 py-0.5 text-xs font-medium rounded-full",
      style: style.presence
    )
  end

  def format_order_money(order)
    return "—" if order.total_sum.blank?

    number_to_currency(order.total_sum, unit: currency_unit(order.currency), format: "%n %u")
  end

  def currency_unit(code)
    { "RUB" => "₽", "RUR" => "₽", "USD" => "$", "EUR" => "€" }[code.to_s.upcase] || code
  end

  def moysklad_order_url(order)
    return nil if order.moysklad_order_id.blank?

    "https://online.moysklad.ru/app/#customerorder/edit?id=#{order.moysklad_order_id}"
  end

  def insales_order_url(order)
    return nil if order.insales_order_id.blank? || order.insale&.api_link.blank?

    host = order.insale.api_link.to_s.sub(%r{\Ahttps?://}, "").chomp("/")
    "https://#{host}/admin/orders/#{order.insales_order_id}"
  end

  def order_display_number(order)
    order.number.presence || "##{order.id}"
  end

  def order_client_name(order)
    return "—" unless order.client

    order.client.try(:full_name).presence || [order.client.name, order.client.surname].compact.join(" ")
  end
end
