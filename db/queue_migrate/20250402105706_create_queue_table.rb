class CreateQueueTable < ActiveRecord::Migration[8.0]
  def change
    create_table :queue_tables do |t|
      t.timestamps
    end
  end
end
