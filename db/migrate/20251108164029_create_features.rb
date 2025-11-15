class CreateFeatures < ActiveRecord::Migration[8.0]
  def change
    create_table :features do |t|
      t.references :product, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.references :characteristic, null: false, foreign_key: true

      t.timestamps
    end

    add_index :features, [:product_id, :property_id], unique: true, name: "index_features_on_product_and_property"
  end
end
