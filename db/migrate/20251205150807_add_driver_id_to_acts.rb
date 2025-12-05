class AddDriverIdToActs < ActiveRecord::Migration[8.0]
  def change
    add_reference :acts, :driver, null: true, foreign_key: { to_table: :users }, index: true
  end
end
