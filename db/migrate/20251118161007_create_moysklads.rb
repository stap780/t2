class CreateMoysklads < ActiveRecord::Migration[8.0]
  def change
    create_table :moysklads do |t|
      t.string :api_key
      t.string :api_password

      t.timestamps
    end
  end
end
