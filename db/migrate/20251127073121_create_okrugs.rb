class CreateOkrugs < ActiveRecord::Migration[8.0]
  def change
    create_table :okrugs do |t|
      t.string :title, null: false
      t.integer :position, default: 1

      t.timestamps
    end
    
    add_index :okrugs, :title, unique: true
  end
end
