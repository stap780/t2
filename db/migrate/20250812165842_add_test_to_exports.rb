class AddTestToExports < ActiveRecord::Migration[8.0]
  def change
    add_column :exports, :test, :boolean, default: false
  end
end
