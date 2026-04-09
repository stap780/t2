class CreateScheduleDays < ActiveRecord::Migration[8.0]
  def change
    create_table :schedule_days do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :shift_code, null: false, foreign_key: true
      t.date :worked_on, null: false

      t.timestamps
    end

    add_index :schedule_days, [:employee_id, :worked_on], unique: true
    add_index :schedule_days, :worked_on
  end
end
