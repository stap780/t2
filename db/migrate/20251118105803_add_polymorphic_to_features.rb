class AddPolymorphicToFeatures < ActiveRecord::Migration[8.0]
  def up
    # Добавляем полиморфную связь
    add_reference :features, :featureable, polymorphic: true, null: true, index: true
    
    # Мигрируем существующие данные
    execute <<-SQL
      UPDATE features 
      SET featureable_type = 'Product', featureable_id = product_id
      WHERE product_id IS NOT NULL
    SQL
    
    # Делаем колонки обязательными после миграции данных
    change_column_null :features, :featureable_type, false
    change_column_null :features, :featureable_id, false
    
    # Удаляем старый индекс
    remove_index :features, name: "index_features_on_product_and_property"
    
    # Удаляем старую колонку product_id
    remove_reference :features, :product, foreign_key: true
    
    # Добавляем новый индекс для уникальности
    add_index :features, [:featureable_type, :featureable_id, :property_id], 
              unique: true, 
              name: "index_features_on_featureable_and_property"
  end

  def down
    # Возвращаем product_id
    add_reference :features, :product, null: true, foreign_key: true
    
    # Мигрируем данные обратно
    execute <<-SQL
      UPDATE features 
      SET product_id = featureable_id
      WHERE featureable_type = 'Product'
    SQL
    
    change_column_null :features, :product_id, false
    
    # Удаляем полиморфные колонки
    remove_index :features, name: "index_features_on_featureable_and_property"
    remove_reference :features, :featureable, polymorphic: true
    
    # Возвращаем старый индекс
    add_index :features, [:product_id, :property_id], 
              unique: true, 
              name: "index_features_on_product_and_property"
  end
end
