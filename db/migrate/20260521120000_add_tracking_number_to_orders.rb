# frozen_string_literal: true

class AddTrackingNumberToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :tracking_number, :string
  end
end
