# frozen_string_literal: true

class CreateAvitos < ActiveRecord::Migration[8.0]
  def change
    create_table :avitos do |t|
      t.string :title
      t.string :api_id
      t.string :api_secret
      t.integer :profileid

      t.timestamps
    end

    add_index :avitos, :api_id, unique: true
    add_index :avitos, :api_secret, unique: true
  end
end
