class CreateActs < ActiveRecord::Migration[8.0]
  def change
    create_table :acts do |t|
      t.string :number
      t.date :date
      t.string :status, default: 'Новый'
      t.references :company, null: false, foreign_key: true
      t.references :strah, null: false, foreign_key: { to_table: :companies }
      t.references :okrug, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :acts, :number
    add_index :acts, :date
    add_index :acts, :status
  end
end
