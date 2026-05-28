# frozen_string_literal: true

class CreateInsalesOrderFieldMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :insales_order_field_mappings do |t|
      t.references :insale, null: false, foreign_key: true
      t.string :source_key, null: false
      t.integer :insales_field_id
      t.string :insales_field_handle
      t.string :insales_field_title
      t.timestamps
    end

    add_index :insales_order_field_mappings,
              %i[insale_id source_key],
              unique: true,
              name: "index_insales_order_field_mappings_on_insale_and_source"
  end
end
