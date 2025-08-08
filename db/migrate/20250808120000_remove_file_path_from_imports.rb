class RemoveFilePathFromImports < ActiveRecord::Migration[8.0]
  def change
    remove_column :imports, :file_path, :string
  end
end
