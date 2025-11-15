class CreateBindings < ActiveRecord::Migration[8.0]
  def change
    create_table :bindings do |t|
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.string :bindable_type, null: false
      t.bigint :bindable_id, null: false
      t.string :value, null: false

      t.timestamps
    end

    add_index :bindings, [:record_type, :record_id]
    add_index :bindings, :value
    add_index :bindings, 
              [:bindable_type, :bindable_id, :record_type, :record_id, :value], 
              unique: true, 
              name: "index_bindings_on_bindable_record_and_value"
  end
end
