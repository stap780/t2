class AddUniqueIndexToImagesPosition < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL.squish
      alter table images add constraint unique_product_id_position unique (product_id, position) deferrable initially deferred;
    SQL
  end

  def down
    execute <<~SQL.squish
      alter table images drop constraint unique_product_id_position
    SQL
  end
end
