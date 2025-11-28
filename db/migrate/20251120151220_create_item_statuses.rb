class CreateItemStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :item_statuses do |t|
      t.string :title
      t.string :color
      t.integer :position, default: 1, null: false

      t.timestamps
    end
  end
end
