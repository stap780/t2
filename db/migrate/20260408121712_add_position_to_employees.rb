class AddPositionToEmployees < ActiveRecord::Migration[8.0]
  def up
    add_column :employees, :position, :integer

    say_with_time "backfill employees.position" do
      Employee.order(:full_name).each.with_index(1) do |emp, i|
        emp.update_column(:position, i)
      end
    end

    change_column_null :employees, :position, false
    add_index :employees, :position, unique: true
  end

  def down
    remove_index :employees, :position
    remove_column :employees, :position
  end
end
