# frozen_string_literal: true

class AddAvitoMarketplaceIdToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :avito_marketplace_id, :string
    add_index :orders, %i[avito_id avito_marketplace_id],
              unique: true,
              where: "avito_marketplace_id IS NOT NULL",
              name: "index_orders_on_avito_id_and_marketplace_id"
  end
end
