class AddXmlTemplatesToExports < ActiveRecord::Migration[8.0]
  def change
    add_column :exports, :layout_template, :text
    add_column :exports, :item_template, :text
  end
end

