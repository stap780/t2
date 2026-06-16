# frozen_string_literal: true

class RequireUniqueProfileidOnAvitos < ActiveRecord::Migration[8.1]
  def up
    Avito.reset_column_information
    Avito.where(profileid: nil).find_each do |avito|
      avito.update_column(:profileid, 70_000_000 + avito.id)
    end

    change_column_null :avitos, :profileid, false
    add_index :avitos, :profileid, unique: true
  end

  def down
    remove_index :avitos, :profileid
    change_column_null :avitos, :profileid, true
  end
end
