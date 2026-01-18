class AddHandleToProperties < ActiveRecord::Migration[8.0]
  def change
    add_column :properties, :handle, :string
    add_index :properties, :handle, unique: true
  end
end
