class Product::ImportSaveData
  # Поля параметров
  PROPERTY_FIELDS = %w[
    pathname station marka model god detal externalcode dtype diametr shob kotv dotv 
    vilet analog weight stupica sdiameter stype swidth sratio video guaranty material avitocat_file
  ].freeze
  
  def initialize(data, properties_cache: {}, characteristics_cache: {})
    @data = data
    @properties_cache = properties_cache
    @characteristics_cache = characteristics_cache
    @product_data = extract_product_data
    @variant_data = extract_variant_data
    @properties_data = extract_properties_data
    @images_urls = extract_images_urls
    @product = nil
  end
  
  def call
    # Находим или создаем товар одним запросом с nested attributes
    product = find_or_create_product_with_nested
    
    {
      success: true,
      product: product,
      images_urls: @images_urls,
      created: product.previously_new_record?
    }
  rescue => e
    {
      success: false,
      error: "#{e.class}: #{e.message}",
      product: @product
    }
  end
  
  private
  
  def extract_product_data
    {
      title: normalize_text(@data[:title] || @data['name']),
      description: normalize_text(@data[:description] || @data['description'])
    }
  end
  
  def extract_variant_data
    {
      barcode: normalize_text(@data[:barcode] || @data['code']),
      sku: normalize_text(@data[:sku] || @data['article']),
      price: parse_decimal(@data[:price] || @data['sale_price']),
      quantity: parse_integer(@data[:quantity]) || 0
    }
  end
  
  def extract_properties_data
    # Извлечение свойств из данных
    properties = {}
    PROPERTY_FIELDS.each do |field|
      value = normalize_text(@data[field.to_sym] || @data[field])
      properties[field] = value if value.present?
    end
    properties
  end
  
  def extract_images_urls
    urls_string = normalize_text(@data[:images_urls] || @data['images_urls'])
    return [] if urls_string.blank?
    urls_string.split(',').map(&:strip).reject(&:blank?)
  end
  
  def find_or_create_product_with_nested
    # Ищем существующий товар
    product = find_existing_product
    
    # Подготавливаем nested attributes
    variants_attrs = prepare_variants_attributes(product)
    features_attrs = prepare_features_attributes(product)
    
    # Создаем или обновляем товар одним запросом
    if product
      # Обновляем существующий товар
      update_attrs = {
        variants_attributes: variants_attrs,
        features_attributes: features_attrs
      }
      
      # Обновляем описание, если оно изменилось
      if @product_data[:description].present? && 
         product.description.to_plain_text != @product_data[:description]
        update_attrs[:description] = @product_data[:description]
      end
      
      product.update!(update_attrs)
      product
    else
      # Создаем новый товар
      Product.create!(
        title: @product_data[:title],
        description: @product_data[:description],
        status: 'draft',
        tip: 'product',
        variants_attributes: variants_attrs,
        features_attributes: features_attrs
      )
    end
  end
  
  def find_existing_product
    product = nil
    
    # Поиск по штрихкоду/SKU варианта
    if @variant_data[:barcode].present? || @variant_data[:sku].present?
      conditions = []
      params = {}
      
      if @variant_data[:barcode].present?
        conditions << "variants.barcode = :barcode"
        params[:barcode] = @variant_data[:barcode]
      end
      
      if @variant_data[:sku].present?
        conditions << "variants.sku = :sku"
        params[:sku] = @variant_data[:sku]
      end
      
      variant = Variant.joins(:product)
                      .where(conditions.join(' OR '), params)
                      .first
      product = variant&.product
    end
    
    # Fallback на поиск по названию
    if product.nil? && @product_data[:title].present?
      product = Product.find_by(title: @product_data[:title])
    end
    
    product
  end
  
  def prepare_variants_attributes(existing_product)
    return [] if @variant_data[:barcode].blank? && @variant_data[:sku].blank?
    
    # Если товар существует, ищем существующий вариант
    if existing_product
      variant = if @variant_data[:barcode].present?
                  existing_product.variants.find_by(barcode: @variant_data[:barcode])
                elsif @variant_data[:sku].present?
                  existing_product.variants.find_by(sku: @variant_data[:sku])
                else
                  nil
                end
      
      if variant
        # Обновляем существующий вариант
        [{
          id: variant.id,
          barcode: @variant_data[:barcode] || variant.barcode,
          sku: @variant_data[:sku] || variant.sku,
          price: @variant_data[:price] || variant.price,
          quantity: @variant_data[:quantity] || variant.quantity
        }]
      else
        # Создаем новый вариант
        [{
          barcode: @variant_data[:barcode],
          sku: @variant_data[:sku],
          price: @variant_data[:price] || 0,
          quantity: @variant_data[:quantity] || 0
        }]
      end
    else
      # Для нового товара создаем вариант
      [{
        barcode: @variant_data[:barcode],
        sku: @variant_data[:sku],
        price: @variant_data[:price] || 0,
        quantity: @variant_data[:quantity] || 0
      }]
    end
  end
  
  def prepare_features_attributes(existing_product)
    return [] if @properties_data.empty?
    
    # Получаем существующие features для обновления
    existing_features = if existing_product
                          existing_product.features.includes(:property, :characteristic).index_by(&:property_id)
                        else
                          {}
                        end
    
    features_attrs = []
    
    @properties_data.each do |property_title, characteristic_value|
      next if characteristic_value.blank?
      
      property = get_or_create_property(property_title.to_s)
      characteristic = get_or_create_characteristic(property, characteristic_value.to_s)
      
      if existing_features[property.id]
        # Обновляем существующий feature
        feature = existing_features[property.id]
        if feature.characteristic_id != characteristic.id
          features_attrs << {
            id: feature.id,
            property_id: property.id,
            characteristic_id: characteristic.id
          }
        end
      else
        # Создаем новый feature
        features_attrs << {
          property_id: property.id,
          characteristic_id: characteristic.id
        }
      end
    end
    
    features_attrs
  end
  
  def get_or_create_property(title)
    return @properties_cache[title] if @properties_cache[title]
    
    property = Property.find_or_create_by!(title: title)
    @properties_cache[title] = property
    property
  end
  
  def get_or_create_characteristic(property, title)
    cache_key = "#{property.id}_#{title}"
    return @characteristics_cache[cache_key] if @characteristics_cache[cache_key]
    
    characteristic = property.characteristics.find_or_create_by!(title: title)
    @characteristics_cache[cache_key] = characteristic
    characteristic
  end
  
  # Helper методы
  def normalize_text(text)
    return nil if text.blank?
    text.to_s.strip.presence
  end
  
  def parse_decimal(value)
    return nil if value.blank?
    value.to_s.gsub(',', '.').to_f
  rescue
    nil
  end
  
  def parse_integer(value)
    return nil if value.blank?
    value.to_s.to_i
  rescue
    nil
  end
end

