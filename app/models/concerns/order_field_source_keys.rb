# frozen_string_literal: true

module OrderFieldSourceKeys
  extend ActiveSupport::Concern

  SOURCE_KEYS = {
    "order.number" => "Номер заказа",
    "order.avito_marketplace_id" => "Номер заказа Avito (marketplaceId)",
    "order.tracking_number" => "Трек / номер отправки",
    "order.comment" => "Заметки заказа",
    "order.total_sum" => "Сумма заказа",
    "client.name" => "Имя клиента",
    "client.email" => "Email клиента",
    "client.phone" => "Телефон клиента"
  }.freeze
end
