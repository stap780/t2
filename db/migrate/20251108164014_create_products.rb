class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.string :status
      t.string :tip
      t.string :title, null: false
      t.text :description

      t.timestamps
    end

    add_index :products, :title
    add_index :products, :status
  end
end
