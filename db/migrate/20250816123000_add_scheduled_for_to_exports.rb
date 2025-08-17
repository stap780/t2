class AddScheduledForToExports < ActiveRecord::Migration[8.0]
  def change
    add_column :exports, :scheduled_for, :datetime
    add_index :exports, :scheduled_for
  end
end
