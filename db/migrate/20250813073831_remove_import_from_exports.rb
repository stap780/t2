class RemoveImportFromExports < ActiveRecord::Migration[8.0]
  def change
    remove_reference :exports, :import, null: false, foreign_key: true
  end
end
