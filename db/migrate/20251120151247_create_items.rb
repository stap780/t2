class CreateItems < ActiveRecord::Migration[8.0]
  def change
    create_table :items do |t|
      t.integer :incase_id
      t.string :title
      t.integer :quantity
      t.string :katnumber
      t.decimal :price, precision: 12, scale: 2, default: "0.0"
      t.decimal :sum, precision: 12, scale: 2, default: "0.0"
      t.integer :item_status_id
      t.integer :variant_id
      t.integer :vat

      t.timestamps
    end
    
    add_index "items", ["variant_id"]
    add_index "items", ["incase_id"]
  end
end
