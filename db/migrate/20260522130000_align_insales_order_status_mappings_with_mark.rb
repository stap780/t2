# frozen_string_literal: true

class AlignInsalesOrderStatusMappingsWithMark < ActiveRecord::Migration[8.1]
  def up
    remove_index :insales_order_status_mappings,
                 name: "index_insales_order_status_mappings_on_insale_and_key",
                 if_exists: true

    rename_column :insales_order_status_mappings, :insales_status_key, :insales_custom_status_permalink
    remove_column :insales_order_status_mappings, :insales_status_title, :string

    add_column :insales_order_status_mappings, :insales_financial_status, :string, null: false, default: "pending"

    execute "DELETE FROM insales_order_status_mappings WHERE insale_id IS NULL"
    change_column_null :insales_order_status_mappings, :insale_id, false

    add_index :insales_order_status_mappings,
              %i[insale_id insales_custom_status_permalink insales_financial_status],
              unique: true,
              name: "index_insales_order_status_mappings_unique"
  end

  def down
    remove_index :insales_order_status_mappings,
                 name: "index_insales_order_status_mappings_unique",
                 if_exists: true

    change_column_null :insales_order_status_mappings, :insale_id, true
    remove_column :insales_order_status_mappings, :insales_financial_status

    add_column :insales_order_status_mappings, :insales_status_title, :string
    rename_column :insales_order_status_mappings, :insales_custom_status_permalink, :insales_status_key

    add_index :insales_order_status_mappings,
              %i[insale_id insales_status_key],
              unique: true,
              name: "index_insales_order_status_mappings_on_insale_and_key"
  end
end
