class AddDefaultValuesToProducts < ActiveRecord::Migration[8.0]
  def change
    change_column_default :products, :status, "draft"
    change_column_default :products, :tip, "product"
  end
end
