class AddFileHeadersToExports < ActiveRecord::Migration[8.0]
  def change
    add_column :exports, :file_headers, :string
  end
end
