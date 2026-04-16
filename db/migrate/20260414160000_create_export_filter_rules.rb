class CreateExportFilterRules < ActiveRecord::Migration[8.0]
  def change
    create_table :export_filter_rules do |t|
      t.references :export, null: false, foreign_key: true
      t.string :rule_key, null: false
      t.string :rule_condition, null: false
      t.text :rule_value
      t.bigint :property_id
      t.bigint :characteristic_id
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :export_filter_rules, [:export_id, :position]
  end
end
