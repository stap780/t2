class CreateCharacteristics < ActiveRecord::Migration[8.0]
  def change
    create_table :characteristics do |t|
      t.references :property, null: false, foreign_key: true
      t.string :title, null: false

      t.timestamps
    end

    add_index :characteristics, [:property_id, :title], unique: true, name: "index_characteristics_on_property_and_title"
  end
end
