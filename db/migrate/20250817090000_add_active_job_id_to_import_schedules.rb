class AddActiveJobIdToImportSchedules < ActiveRecord::Migration[7.1]
  def change
    add_column :import_schedules, :active_job_id, :string
    add_index :import_schedules, :active_job_id
  end
end
