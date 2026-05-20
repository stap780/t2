# frozen_string_literal: true

class AddOrderSettingsToMoysklads < ActiveRecord::Migration[8.0]
  def change
    change_table :moysklads, bulk: true do |t|
      t.string :organization_href
      t.string :agent_href
      t.string :store_href
    end
  end
end
