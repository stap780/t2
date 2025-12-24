class Dashboard < ApplicationRecord

  SEARCHABLE_MODEL_ATTRIBUTES = {
    'Incase' => %w[unumber carnumber stoanumber],
    'User' => %w[email_address],
    'Company' => %w[short_title title],
    'Variant' => %w[sku barcode],
    'Product' => %w[title]
  }

  def self.search(query)
    results = {}
    
    if query.present?
      SEARCHABLE_MODEL_ATTRIBUTES.each do |model_name, searchable_fields|
        model_class = model_name.constantize
        
        # Специальная обработка для Variant (поиск по product.title через joins)
        if model_name == 'Variant'
          model_results = model_class.joins(:product)
            .ransack("#{searchable_fields.join('_or_')}_or_product_title_matches_all": "%#{query}%")
            .result(distinct: true)
          display_fields = ['product_id'] + searchable_fields + ['product_title']
        else
          model_results = model_class.ransack(
            "#{searchable_fields.join('_or_')}_matches_all": "%#{query}%"
          ).result(distinct: true)
          display_fields = ['id'] + searchable_fields
        end
        
        converted_results = model_results.limit(10).map do |item|
          if model_name == 'Variant'
            [
              item.product_id,
              item.sku,
              item.barcode,
              item.product.title
            ]
          else
            display_fields.map { |attr| item.send(attr) }
          end
        end
        
        results[model_name] = converted_results if converted_results.any?
      end
    end
    
    results
  end
end

