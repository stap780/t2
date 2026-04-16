class AddRansackQueryToExports < ActiveRecord::Migration[8.0]
  def change
    add_column :exports, :ransack_query, :jsonb, default: {}, null: false
  end
end
