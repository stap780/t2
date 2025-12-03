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
              { success: true, message: "Успешно обновили цену ОСЗЗ", price: oszz_price_value }
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

end
