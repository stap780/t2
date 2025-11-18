class CreateDetals < ActiveRecord::Migration[8.0]
  def change
    create_table :detals do |t|
      t.boolean :status
      t.string :sku
      t.string :title
      t.text :desc

      t.timestamps
    end
  end
end
