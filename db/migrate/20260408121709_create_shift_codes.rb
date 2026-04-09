class CreateShiftCodes < ActiveRecord::Migration[8.0]
  def change
    create_table :shift_codes do |t|
      t.string :code, null: false
      t.string :label, null: false
      t.string :color
      t.integer :position, default: 0, null: false
      t.boolean :vacation, default: false, null: false
      t.boolean :day_off, default: false, null: false

      t.timestamps
    end

    add_index :shift_codes, :code, unique: true
  end
end
