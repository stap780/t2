# frozen_string_literal: true

class CreateMoyskladOrderSourceMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :moysklad_order_source_mappings do |t|
      t.references :moysklad, null: false, foreign_key: true
      t.string :source_key, null: false
      t.string :ms_attribute_href, null: false
      t.string :ms_attribute_name
      t.string :ms_custom_entity_href, null: false
      t.string :ms_custom_entity_name

      t.timestamps
    end

    add_index :moysklad_order_source_mappings,
              %i[moysklad_id source_key],
              unique: true,
              name: "index_ms_order_source_mappings_on_moysklad_and_source"
  end
end
