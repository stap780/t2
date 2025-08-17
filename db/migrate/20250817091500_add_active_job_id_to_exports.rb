class AddActiveJobIdToExports < ActiveRecord::Migration[7.1]
  def change
    add_column :exports, :active_job_id, :string
    add_index :exports, :active_job_id
  end
end
