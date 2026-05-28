# frozen_string_literal: true

class SimplifyMoyskladDefaultAdSource < ActiveRecord::Migration[8.1]
  def change
    drop_table :moysklad_order_source_mappings, if_exists: true do |t|
      t.bigint "moysklad_id", null: false
      t.string "ms_attribute_href", null: false
      t.string "ms_attribute_name"
      t.string "ms_custom_entity_href", null: false
      t.string "ms_custom_entity_name"
      t.string "source_key"
      t.bigint "avito_id"
      t.bigint "insale_id"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
    end

    change_table :moysklads, bulk: true do |t|
      t.string :default_ad_source_href
      t.string :default_ad_source_name
    end
  end
end
