class AddOszzPriceToDetals < ActiveRecord::Migration[8.0]
  def change
    add_column :detals, :oszz_price, :decimal, precision: 12, scale: 2, default: 0.0
  end
end
