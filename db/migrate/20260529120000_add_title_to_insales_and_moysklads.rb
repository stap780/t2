# frozen_string_literal: true

class AddTitleToInsalesAndMoysklads < ActiveRecord::Migration[8.1]
  def up
    add_column :insales, :title, :string
    add_column :moysklads, :title, :string

    Insale.reset_column_information
    Insale.where(title: [nil, ""]).find_each do |insale|
      insale.update_column(:title, insale.api_link)
    end

    Moysklad.reset_column_information
    Moysklad.where(title: [nil, ""]).update_all(title: "МойСклад")
  end

  def down
    remove_column :insales, :title
    remove_column :moysklads, :title
  end
end
