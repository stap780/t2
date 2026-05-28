# frozen_string_literal: true

class MoyskladOrderIntegrationSettings < ActiveRecord::Migration[8.0]
  def change
    change_table :moysklads, bulk: true do |t|
      t.string :order_number_prefix
    end

    change_table :clients, bulk: true do |t|
      t.string :moysklad_counterparty_href
    end

    create_table :moysklad_order_field_mappings do |t|
      t.references :moysklad, null: false, foreign_key: true
      t.string :source_key, null: false
      t.string :ms_attribute_href, null: false
      t.string :ms_attribute_name
      t.timestamps
    end

    add_index :moysklad_order_field_mappings,
              %i[moysklad_id source_key],
              unique: true,
              name: "index_ms_order_field_mappings_on_moysklad_and_source"
  end
end
