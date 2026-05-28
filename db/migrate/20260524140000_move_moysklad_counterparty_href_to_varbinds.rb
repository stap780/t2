# frozen_string_literal: true

class MoveMoyskladCounterpartyHrefToVarbinds < ActiveRecord::Migration[8.0]
  def up
    return unless column_exists?(:clients, :moysklad_counterparty_href)

    moysklad = Moysklad.order(:id).first
    if moysklad
      Client.where.not(moysklad_counterparty_href: [nil, ""]).find_each do |client|
        uuid = extract_counterparty_uuid(client.moysklad_counterparty_href)
        next if uuid.blank?

        Varbind.find_or_create_by!(record: client, bindable: moysklad) do |varbind|
          varbind.value = uuid
        end
      end
    end

    remove_column :clients, :moysklad_counterparty_href
  end

  def down
    add_column :clients, :moysklad_counterparty_href, :string

    Moysklad.find_each do |moysklad|
      Varbind.where(bindable: moysklad, record_type: "Client").find_each do |varbind|
        varbind.record.update_column(
          :moysklad_counterparty_href,
          "https://api.moysklad.ru/api/remap/1.2/entity/counterparty/#{varbind.value}"
        )
      end
    end
  end

  private

  def extract_counterparty_uuid(href)
    href.to_s[%r{/counterparty/([^/?]+)}, 1]
  end
end
