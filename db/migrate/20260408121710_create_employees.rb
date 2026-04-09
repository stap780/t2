class CreateEmployees < ActiveRecord::Migration[8.0]
  def change
    create_table :employees do |t|
      t.string :full_name, null: false
      t.references :department, null: true, foreign_key: true
      t.references :manager, null: true, foreign_key: { to_table: :employees }
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :employees, :full_name
  end
end
