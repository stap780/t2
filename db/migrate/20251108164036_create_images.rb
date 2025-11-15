class CreateImages < ActiveRecord::Migration[8.0]
  def change
    create_table :images do |t|
      t.references :product, null: false, foreign_key: true
      t.integer :position

      t.timestamps
    end

    add_index :images, :position
  end
end
