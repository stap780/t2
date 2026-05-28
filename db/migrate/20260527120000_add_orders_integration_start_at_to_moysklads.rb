# frozen_string_literal: true

class AddOrdersIntegrationStartAtToMoysklads < ActiveRecord::Migration[8.1]
  def change
    add_column :moysklads, :orders_integration_start_at, :datetime
  end
end
