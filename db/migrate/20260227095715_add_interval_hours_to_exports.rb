class AddIntervalHoursToExports < ActiveRecord::Migration[8.0]
  def change
    add_column :exports, :interval_hours, :integer
  end
end
