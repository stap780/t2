class Detal < ApplicationRecord
  require 'rest-client'
  require 'json'
  require 'uri'
  require 'cgi'

  validates :title, presence: true

  has_many :features, as: :featureable, dependent: :destroy
  has_many :properties, through: :features
  accepts_nested_attributes_for :features, allow_destroy: true

  # Ransack для поиска
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[properties features]
  end

  # Получение цены ОСЗЗ по артикулу
  def get_oszz
    return { success: false, message: "SKU отсутствует" } if sku.blank?

    base_url = "http://new.api.oszz.ru/2/search"
    params = {
      q: sku,
      tokenId: Rails.application.credentials.dig(:oszz_token_id),
      format: "json"
    }
    url = "#{base_url}?#{params.map { |k, v| "#{k}=#{CGI.escape(v.to_s)}" }.join('&')}"
    begin
      RestClient::Request.execute(url: url, method: :get, verify_ssl: false, max_redirects: 0 ) do |response, request, result, &block|
        case response.code
        when 200
          data = JSON.parse(response)
          result_data = data['result']
          
          if result_data.present?
            is_original_prices = result_data.map { |r| r['price'] if r['isOriginal'] == true }
            oszz_price_value = is_original_prices.reject(&:blank?).present? ? 
              is_original_prices.reject(&:blank?).sort_by(&:to_i).first : nil
            
            if oszz_price_value
              { success: true, message: "Успешно получили цену ОСЗЗ", price: oszz_price_value }
            else
              { success: false, message: "Не нашли на сайте ОСЗ модель-деталь по оригинальному номеру" }
            end
          else
            { success: false, message: "Нет результатов в ответе API" }
          end
        when 400
          Rails.logger.error "OSZZ API Error 400: #{url}"
          { success: false, message: "Error 400", error_code: 400 }
        when 404
          Rails.logger.error "OSZZ API Error 404: #{url}"
          { success: false, message: "Error 404", error_code: 404 }
        when 302
          Rails.logger.error "OSZZ API Error 302: #{result}"
          { success: false, message: "Error 302", error_code: 302 }
        else
          response.return!(&block)
        end
      end
    rescue RestClient::ExceptionWithResponse => e
      Rails.logger.error "OSZZ API Exception: #{e.message}"
      { success: false, message: "Ошибка при запросе к API: #{e.message}", error: e.class.name }
    rescue JSON::ParserError => e
      Rails.logger.error "OSZZ API JSON Parse Error: #{e.message}"
      { success: false, message: "Ошибка парсинга ответа API", error: e.class.name }
    rescue => e
      Rails.logger.error "OSZZ API Unexpected Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, message: "Неожиданная ошибка: #{e.message}", error: e.class.name }
    end
  end

  def variants
    Variant.where(sku: sku)
  end

  def copy_features_from_products
    return { success: false, message: "SKU отсутствует" } if sku.blank?
    
    # Найти все variants с таким же sku
    variants = Variant.where(sku: sku)
    return { success: false, message: "Товары с таким артикулом не найдены" } if variants.empty?
    
    # Получить все products
    product_ids = variants.pluck(:product_id).uniq
    products = Product.where(id: product_ids).includes(:features)
    
    return { success: false, message: "Товары не найдены" } if products.empty?
    
    # Собрать все features из товаров
    copied_count = 0
    skipped_count = 0
    existing_property_ids = features.pluck(:property_id)
    
    products.each do |product|
      product.features.each do |product_feature|
        # Пропускаем, если такой property уже есть в детали
        if existing_property_ids.include?(product_feature.property_id)
          skipped_count += 1
          next
        end
        
        # Создаем новый feature для детали
        begin
          features.create!(
            property_id: product_feature.property_id,
            characteristic_id: product_feature.characteristic_id
          )
          copied_count += 1
          existing_property_ids << product_feature.property_id
        rescue => e
          Rails.logger.error "Error copying feature: #{e.message}"
          # Продолжаем обработку других features
        end
      end
    end
    
    if copied_count > 0
      { success: true, message: "Скопировано #{copied_count} параметров", count: copied_count, skipped: skipped_count }
    else
      { success: false, message: "Не удалось скопировать параметры. Все параметры уже присутствуют в детали или произошла ошибка." }
    end
  end

end
