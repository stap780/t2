class RemoveImageLinkFromVariants < ActiveRecord::Migration[8.0]
  def change
    remove_column :variants, :image_link, :string
  end
end
