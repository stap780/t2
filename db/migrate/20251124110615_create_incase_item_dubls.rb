class CreateIncaseItemDubls < ActiveRecord::Migration[8.0]
  def change
    create_table :incase_item_dubls do |t|
      t.references :incase_dubl, null: false, foreign_key: true
      t.string :title
      t.integer :quantity
      t.string :katnumber
      t.decimal :price, precision: 12, scale: 2, default: 0.0
      t.string :supplier_code

      t.timestamps
    end
  end
end
