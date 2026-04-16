class RemoveRansackQueryFromExports < ActiveRecord::Migration[8.0]
  def change
    remove_column :exports, :ransack_query, :jsonb, default: {}, null: false
  end
end
