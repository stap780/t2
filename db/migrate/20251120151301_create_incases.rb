class CreateIncases < ActiveRecord::Migration[8.0]
  def change
    create_table :incases do |t|
      t.string :region
      t.integer :strah_id
      t.string :stoanumber
      t.string :unumber
      t.integer :company_id
      t.string :carnumber
      t.datetime :date
      t.string :modelauto
      t.decimal :totalsum, precision: 12, scale: 2, default: "0.0"
      t.string :incase_status_id
      t.string :incase_tip_id

      t.timestamps
    end
    
    add_foreign_key "incases", "companies", column: "company_id"
    add_foreign_key "incases", "companies", column: "strah_id"
    add_index "incases", ["company_id"]
    add_index "incases", ["strah_id"]
  end
end
