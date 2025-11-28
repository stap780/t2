class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :inn
      t.string :kpp
      t.string :title
      t.string :short_title
      t.string :ur_address
      t.string :fact_address
      t.string :ogrn
      t.string :okpo
      t.string :bik
      t.string :bank_title
      t.string :bank_account
      t.string :tip
      t.integer :okrug_id
      t.text :info

      t.timestamps
    end
    
    add_index "companies", ["short_title"]
    add_index "companies", ["tip"]
  end
end
