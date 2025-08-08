class CreateImports < ActiveRecord::Migration[8.0]
  def change
    create_table :imports do |t|
      t.string :name, null: false
      t.string :file_path
      t.string :status, default: 'pending', null: false
      t.datetime :imported_at
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :imports, :status
    add_index :imports, :imported_at
  end
end
