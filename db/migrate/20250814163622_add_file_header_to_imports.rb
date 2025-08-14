class AddFileHeaderToImports < ActiveRecord::Migration[8.0]
  def change
    add_column :imports, :file_header, :string
  end
end
