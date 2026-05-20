# frozen_string_literal: true

class CreateOrdersRegistry < ActiveRecord::Migration[8.0]
  def change
    create_table :order_statuses do |t|
      t.string :code, null: false
      t.string :title, null: false
      t.string :color
      t.integer :position, default: 1, null: false
      t.boolean :is_terminal, default: false, null: false

      t.timestamps
    end
    add_index :order_statuses, :code, unique: true
    add_index :order_statuses, :position

    create_table :orders do |t|
      t.references :client, null: true, foreign_key: true
      t.references :order_status, null: true, foreign_key: true
      t.string :source, null: false
      t.string :number
      t.decimal :total_sum, precision: 12, scale: 2
      t.string :currency, default: "RUB", null: false
      t.text :comment

      t.string :moysklad_order_id
      t.string :moysklad_external_code
      t.string :last_moysklad_state_href

      t.references :avito, null: true, foreign_key: true
      t.string :avito_order_id
      t.string :avito_status_sent

      t.references :insale, null: true, foreign_key: true
      t.string :insales_order_id

      t.datetime :synced_at

      t.timestamps
    end
    add_index :orders, :source
    add_index :orders, :number
    add_index :orders, :moysklad_order_id, unique: true, where: "moysklad_order_id IS NOT NULL"
    add_index :orders, %i[avito_id avito_order_id], unique: true, where: "avito_order_id IS NOT NULL"
    add_index :orders, %i[insale_id insales_order_id], unique: true, where: "insales_order_id IS NOT NULL"

    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true
      t.references :variant, null: true, foreign_key: true
      t.integer :quantity, null: false, default: 1
      t.decimal :price, precision: 12, scale: 2
      t.integer :vat, default: 0, null: false
      t.string :title
      t.string :sku

      t.timestamps
    end

    create_table :moysklad_order_status_mappings do |t|
      t.string :moysklad_state_href, null: false
      t.string :moysklad_state_name
      t.references :order_status, null: false, foreign_key: true

      t.timestamps
    end
    add_index :moysklad_order_status_mappings, :moysklad_state_href, unique: true

    create_table :avito_order_status_mappings do |t|
      t.references :order_status, null: false, foreign_key: true, index: { unique: true }
      t.string :avito_status, null: false

      t.timestamps
    end

    create_table :insales_order_status_mappings do |t|
      t.references :insale, null: true, foreign_key: true
      t.string :insales_status_key, null: false
      t.string :insales_status_title
      t.references :order_status, null: false, foreign_key: true

      t.timestamps
    end
    add_index :insales_order_status_mappings, %i[insale_id insales_status_key],
              unique: true,
              name: "index_insales_order_status_mappings_on_insale_and_key"
  end
end
