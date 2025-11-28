class CreateClientCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :client_companies do |t|
      t.references :client, null: false, foreign_key: true
      t.references :company, null: false, foreign_key: true

      t.timestamps
    end
  end
end
