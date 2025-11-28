class AddSupplierCodeToItems < ActiveRecord::Migration[8.0]
  def change
    add_column :items, :supplier_code, :string
  end
end
