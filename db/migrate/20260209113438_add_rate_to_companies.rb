class AddRateToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :rate, :decimal, precision: 5, scale: 2, default: 100.0, null: true
  end
end
