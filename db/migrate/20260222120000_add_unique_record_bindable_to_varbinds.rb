# frozen_string_literal: true

class AddUniqueRecordBindableToVarbinds < ActiveRecord::Migration[8.0]
  def change
    add_index :varbinds,
              [:record_type, :record_id, :bindable_type, :bindable_id],
              unique: true,
              name: "index_varbinds_on_record_and_bindable_unique"
  end
end
