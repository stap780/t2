class AddWeekdaysToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :weekdays, :jsonb, default: []
    add_index :companies, :weekdays, using: :gin
  end
end
