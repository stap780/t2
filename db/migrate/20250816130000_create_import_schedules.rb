class CreateImportSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :import_schedules do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :time, null: false
      t.string :recurrence, null: false, default: 'daily'
      t.datetime :scheduled_for
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :import_schedules, :scheduled_for
  end
end
