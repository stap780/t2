class CreateActItems < ActiveRecord::Migration[8.0]
  def change
    create_table :act_items do |t|
      t.references :act, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :act_items, [:act_id, :item_id], unique: true
  end
end
