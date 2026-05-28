# frozen_string_literal: true

class AddAvitoIdToAvitoOrderStatusMappings < ActiveRecord::Migration[8.0]
  def up
    add_reference :avito_order_status_mappings, :avito, foreign_key: true

    first_avito_id = select_value("SELECT id FROM avitos ORDER BY id LIMIT 1")
    if first_avito_id
      execute <<~SQL.squish
        UPDATE avito_order_status_mappings SET avito_id = #{first_avito_id.to_i} WHERE avito_id IS NULL
      SQL
    else
      execute "DELETE FROM avito_order_status_mappings WHERE avito_id IS NULL"
    end

    change_column_null :avito_order_status_mappings, :avito_id, false

    remove_index :avito_order_status_mappings,
                 name: "index_avito_order_status_mappings_on_order_status_id",
                 if_exists: true
    add_index :avito_order_status_mappings,
              %i[avito_id order_status_id],
              unique: true,
              name: "index_avito_order_status_mappings_on_avito_and_order_status"
  end

  def down
    remove_index :avito_order_status_mappings,
                 name: "index_avito_order_status_mappings_on_avito_and_order_status",
                 if_exists: true
    add_index :avito_order_status_mappings,
              :order_status_id,
              unique: true,
              name: "index_avito_order_status_mappings_on_order_status_id"

    remove_reference :avito_order_status_mappings, :avito, foreign_key: true
  end
end
