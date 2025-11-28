class AddForeignKeysToItems < ActiveRecord::Migration[8.0]
  def change
    add_foreign_key "items", "incases"
    add_foreign_key "items", "variants"
  end
end
