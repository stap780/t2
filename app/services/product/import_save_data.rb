class Product::ImportSaveData
  # Маппинг полей CSV на названия свойств (Property)
  PROPERTY_MAPPING = {
    'id' => 'Старый ID',
    'pathname' => 'Состояние',
    'station' => 'Станция',
    'marka' => 'Марка',
    'model' => 'Модель',
    'god' => 'Год',
    'detal' => 'Деталь',
    'externalcode' => 'Внешний код',
    'dtype' => 'Тип диска',
    'diametr' => 'Диаметр',
    'shob' => 'Ширина обода',
    'kotv' => 'К-во отверстий',
    'dotv' => 'Диаметр отверстий',
    'vilet' => 'Вылет',
    'analog' => 'Аналог',
    'weight' => 'Вес',
    'stupica' => 'Ступица (DIA)',
    'sdiameter' => 'Диаметр, дюймы',
    'stype' => 'Сезонность шин',
    'swidth' => 'Ширина профиля шины',
    'sratio' => 'Высота профиля шины',
    'video' => 'Видео',
    'guaranty' => 'Гарантия',
    'material' => 'Материал',
    'avitocat_file' => 'Avito категория',
    'avitocat_code' => 'Avito код',
    'avitocat_name' => 'Avito название'
  }.freeze
  
  def initialize(data, properties_cache: {}, characteristics_cache: {})
    @data = data

    # Если нам не передали кэши (или передали пустые), используем
    # кэш, общий для процесса воркера, чтобы не гонять их через аргументы job'ов.
    default_properties_cache, default_characteristics_cache = self.class.load_caches
    @properties_cache = properties_cache.presence || default_properties_cache
    @characteristics_cache = characteristics_cache.presence || default_characteristics_cache
    @product_data = extract_product_data
    @variant_data = extract_variant_data
    @properties_data = extract_properties_data
    @images_urls = extract_images_urls
    @msid = normalize_text(@data[:msid])
    @insid = normalize_text(@data[:insid])
    @product = nil
    @existing_variant = nil  # Кэш для найденного варианта
  end
  
  def call
    # Находим или создаем товар одним запросом с nested attributes
    product = find_or_create_product_with_nested
    
    # Создаем varbinds для варианта после создания/обновления
    create_varbinds_for_variant(product) if product.persisted?
    
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
      # из CSV приходит "name" и "description"
      title: normalize_text(@data[:title] || @data[:name]),
      description: normalize_text(@data[:description])
    }
  end
  
  def extract_variant_data
    {
      # из CSV приходят "code", "article", "sale_price", "quantity"
      barcode: normalize_text(@data[:barcode] || @data[:code]),
      sku: normalize_text(@data[:sku] || @data[:article]),
      price: parse_decimal(@data[:price] || @data[:sale_price]),
      quantity: parse_integer(@data[:quantity]) || 0
    }
  end
  
  def extract_properties_data
    # Извлечение свойств из данных с использованием маппинга
    properties = {}
    
    # Используем маппинг: CSV поле -> Property название
    PROPERTY_MAPPING.each do |csv_field, property_title|
      # thanks to with_indifferent_access достаточно строкового ключа
      value = normalize_text(@data[csv_field])
      properties[property_title] = value if value.present?
    end
    
    properties
  end
  
  def extract_images_urls
    urls_string = normalize_text(@data[:images_urls])
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
      
      # Обновляем название, если оно изменилось
      if @product_data[:title].present? && 
         product.title != @product_data[:title]
        update_attrs[:title] = @product_data[:title]
      end
      
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
    # Поиск только по штрихкоду варианта
    return nil unless @variant_data[:barcode].present?
    
    @existing_variant = Variant.joins(:product)
                              .where(barcode: @variant_data[:barcode])
                              .first
    
    @existing_variant&.product
  end
  
  def prepare_variants_attributes(existing_product)
    return [] if @variant_data[:barcode].blank?
    
    # Если товар существует, используем уже найденный вариант (только по штрихкоду)
    if existing_product
      variant = @existing_variant
      
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

  # Кэш свойств и характеристик на уровне процесса воркера
  def self.load_caches
    if defined?(@@properties_cache) && @@properties_cache.present? &&
       defined?(@@characteristics_cache) && @@characteristics_cache.present?
      return [@@properties_cache, @@characteristics_cache]
    end

    properties_cache = {}
    characteristics_cache = {}

    Property.includes(:characteristics).find_each do |property|
      properties_cache[property.title] = property

      property.characteristics.each do |characteristic|
        cache_key = "#{property.id}_#{characteristic.title}"
        characteristics_cache[cache_key] = characteristic
      end
    end

    @@properties_cache = properties_cache
    @@characteristics_cache = characteristics_cache

    [@@properties_cache, @@characteristics_cache]
  end
  
  def create_varbinds_for_variant(product)
    # Используем уже найденный вариант, если он есть
    # Иначе ищем вариант в товаре по штрихкоду (после создания/обновления через nested attributes)
    variant = @existing_variant || (@variant_data[:barcode].present? ? product.variants.find_by(barcode: @variant_data[:barcode]) : nil)
    
    return unless variant
    
    # Создаем varbind для insid (InSales)
    if @insid.present?
      insale = Insale.first
      if insale
        variant.bindings.find_or_create_by!(
          bindable: insale,
          value: @insid
        )
      end
    end
    
    # Создаем varbind для msid (MoySklad)
    if @msid.present?
      moysklad = Moysklad.first
      if moysklad
        variant.bindings.find_or_create_by!(
          bindable: moysklad,
          value: @msid
        )
      end
    end
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

