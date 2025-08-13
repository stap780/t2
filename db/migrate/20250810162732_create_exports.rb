class CreateExports < ActiveRecord::Migration[8.0]
  def change
    create_table :exports do |t|
      t.string :name, null: false
      t.string :format, null: false, default: 'csv'
      t.string :status, null: false, default: 'pending'
      t.text :template
      t.datetime :exported_at
      t.string :error_message
      t.references :user, null: false, foreign_key: true
      t.references :import, null: false, foreign_key: true

      t.timestamps
    end
    
    # Add indexes for performance following Rails 8 best practices
    add_index :exports, :status
    add_index :exports, :format
    add_index :exports, :exported_at
    add_index :exports, [:user_id, :created_at]
  end
end
