class CreateIncaseImports < ActiveRecord::Migration[8.0]
  def change
    create_table :incase_imports do |t|
      t.references :user, null: false, foreign_key: true
      t.string :status, default: 'pending', null: false
      t.text :error_message
      t.jsonb :import_errors, default: []
      t.integer :success_count, default: 0
      t.integer :failed_count, default: 0
      t.integer :total_rows, default: 0
      t.datetime :imported_at

      t.timestamps
    end
    
    add_index :incase_imports, :status
    add_index :incase_imports, :created_at
  end
end
