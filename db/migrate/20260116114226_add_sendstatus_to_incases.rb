class AddSendstatusToIncases < ActiveRecord::Migration[8.0]
  def change
    add_column :incases, :sendstatus, :boolean, default: nil, null: true
    add_index :incases, :sendstatus
  end
end
