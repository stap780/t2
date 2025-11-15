class CreateProperties < ActiveRecord::Migration[8.0]
  def change
    create_table :properties do |t|
      t.string :title, null: false

      t.timestamps
    end

    add_index :properties, :title, unique: true
  end
end
