class CreateIncaseDubls < ActiveRecord::Migration[8.0]
  def change
    create_table :incase_dubls do |t|
      t.string :region
      t.integer :strah_id
      t.string :stoanumber
      t.string :unumber
      t.integer :company_id
      t.string :carnumber
      t.datetime :date
      t.string :modelauto
      t.decimal :totalsum
      t.references :incase_import, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :incase_dubls, :unumber
    add_index :incase_dubls, [:unumber, :stoanumber]
  end
end
