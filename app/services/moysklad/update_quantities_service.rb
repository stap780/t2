require 'rest-client'
require 'base64'
require 'json'

class Moysklad::UpdateQuantitiesService
  MOYSKLAD_API_URL = "https://api.moysklad.ru/api/remap/1.2/report/stock/bystore/current".freeze
  
  # Email для уведомлений (можно вынести в настройки)
  NOTIFICATION_EMAIL = Rails.application.credentials.dig(:moysklad_notification_email) || 'dizautodealer@gmail.com'
  
  MS_SKLAD_MAPPING = {
    '381569e6-4f34-11e6-7a69-9711000bbbe5' => 'Волгоградский проспект',
    '79f911fc-fb81-11e7-7a31-d0fd001bf68c' => 'Котельники',
    '89dd64b8-4eba-11ed-0a80-0efd00020013' => 'Расходники ТО',
    'ef79a2a8-ae0e-11e8-9107-50480010c0b2' => 'Отрадное',
    'a2aa9dbc-d225-11ee-0a80-06b8001cca60' => 'Неликвид',
    '27ea652f-d182-11ef-0a80-11a600285a13' => 'ШиловоМ5'
  }.freeze

  def initialize(moysklad_config = nil)
    @moysklad = moysklad_config || Moysklad.first
    raise ArgumentError, "Moysklad configuration not found" unless @moysklad
    raise ArgumentError, "Moysklad API credentials missing" unless @moysklad.api_key.present? && @moysklad.api_password.present?
  end

  def call
    Rails.logger.info "Moysklad::UpdateQuantitiesService: Starting quantity update at #{Time.zone.now}"
    
    # Обнуляем все остатки перед обновлением
    Variant.update_all(quantity: 0)
    Rails.logger.info "Moysklad::UpdateQuantitiesService: Reset all variant quantities to 0"
    
    data = fetch_stock_data
    unless data.present?
      result = { success: false, error: "No data received from API" }
      create_email_delivery_and_notify(result)
      return result
    end
    
    updated_count = update_variant_quantities(data)
    stations_updated = update_variant_stations(data)
    
    with_quantity_count = Variant.where('quantity > 0').count
    
    Rails.logger.info "Moysklad::UpdateQuantitiesService: Updated #{updated_count} variants, #{stations_updated} stations updated, #{with_quantity_count} variants with quantity > 0"
    
    result = { 
      success: true, 
      updated_count: updated_count,
      stations_updated: stations_updated,
      with_quantity_count: with_quantity_count
    }
    
    # Создаем EmailDelivery запись и отправляем уведомление
    create_email_delivery_and_notify(result)
    
    result
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error "Moysklad::UpdateQuantitiesService: API error - #{e.response.code}: #{e.response.body}"
    result = { success: false, error: "API error: #{e.response.code} - #{e.response.body}" }
    create_email_delivery_and_notify(result, e.class.name)
    result
  rescue StandardError => e
    Rails.logger.error "Moysklad::UpdateQuantitiesService: Error - #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    result = { success: false, error: "Service error: #{e.message}" }
    create_email_delivery_and_notify(result, e.class.name)
    result
  end

  private

  def fetch_stock_data
    auth = authorization_header
    max_retries = 3
    retry_count = 0
    
    loop do
      begin
        response = RestClient::Request.execute(
          method: :get, 
          url: MOYSKLAD_API_URL, 
          headers: { 
            Authorization: auth,
            Accept: 'application/json;charset=utf-8'
          }
        )
        
        case response.code
        when 200
          Rails.logger.info "Moysklad::UpdateQuantitiesService: API response 200 - OK"
          return JSON.parse(response.body)
        when 404
          Rails.logger.error "Moysklad::UpdateQuantitiesService: API response 404 - Not Found"
          return []
        when 500, 502, 503, 504, 408
          if retry_count < max_retries
            retry_count += 1
            Rails.logger.warn "Moysklad::UpdateQuantitiesService: API response #{response.code} - retry #{retry_count}/#{max_retries} in 1 minute"
            sleep(60)
            next
          else
            Rails.logger.error "Moysklad::UpdateQuantitiesService: Max retries reached for #{response.code}"
            return []
          end
        when 422
          Rails.logger.error "Moysklad::UpdateQuantitiesService: API response 422 - Validation Error"
          error_data = JSON.parse(response.body) rescue {}
          Rails.logger.error "Error details: #{error_data.inspect}"
          return []
        else
          Rails.logger.error "Moysklad::UpdateQuantitiesService: Unexpected API response #{response.code}"
          return []
        end
      rescue RestClient::ExceptionWithResponse => e
        if [500, 502, 503, 504, 408].include?(e.response.code) && retry_count < max_retries
          retry_count += 1
          Rails.logger.warn "Moysklad::UpdateQuantitiesService: Retry #{retry_count}/#{max_retries} after error #{e.response.code}"
          sleep(60)
          next
        else
          Rails.logger.error "Moysklad::UpdateQuantitiesService: API error after retries: #{e.response.code} - #{e.response.body}"
          return []
        end
      rescue StandardError => e
        Rails.logger.error "Moysklad::UpdateQuantitiesService: Unexpected error: #{e.class} - #{e.message}"
        return []
      end
    end
  end

  def update_variant_quantities(data)
    return 0 unless data.is_a?(Array) && data.any?
    
    # Оптимизация: собираем все assortment_id и загружаем varbinds одним запросом
    all_assortment_ids = data.map { |d| d['assortmentId'] }.compact.uniq
    return 0 if all_assortment_ids.empty?
    
    varbinds = Varbind.where(
      bindable_type: 'Moysklad',
      bindable_id: @moysklad.id,
      record_type: 'Variant',
      value: all_assortment_ids
    ).includes(:record)
    
    # Создаем маппинг assortment_id -> variant
    variant_map = {}
    varbinds.each do |varbind|
      variant_map[varbind.value] = varbind.record if varbind.record.is_a?(Variant)
    end
    
    # Группируем данные по остатку и обновляем батчами
    data_group_by_stock = data.group_by { |d| d['stock'] || 0 }
    updated_count = 0
    
    data_group_by_stock.each do |stock_quantity, items|
      quantity = stock_quantity < 1 ? 0 : stock_quantity.to_i
      variant_ids = items.map { |item| variant_map[item['assortmentId']]&.id }.compact
      
      if variant_ids.any?
        Variant.where(id: variant_ids).update_all(quantity: quantity)
        updated_count += variant_ids.size
      end
    end
    
    updated_count
  end

  def update_variant_stations(data)
    return 0 unless data.is_a?(Array) && data.any?
    
    # Оптимизация: собираем все assortment_id и загружаем varbinds одним запросом
    all_assortment_ids = data.map { |d| d['assortmentId'] }.compact.uniq
    return 0 if all_assortment_ids.empty?
    
    varbinds = Varbind.where(
      bindable_type: 'Moysklad',
      bindable_id: @moysklad.id,
      record_type: 'Variant',
      value: all_assortment_ids
    ).includes(record: :product)
    
    # Создаем маппинг assortment_id -> variant
    variant_map = {}
    varbinds.each do |varbind|
      variant_map[varbind.value] = varbind.record if varbind.record.is_a?(Variant)
    end
    
    # Группируем по складу и обновляем feature "Станция"
    data_group_by_store = data.group_by { |d| d['storeId'] }
    stations_updated = 0
    
    data_group_by_store.each do |store_id, items|
      station_name = MS_SKLAD_MAPPING[store_id]
      next unless station_name.present?
      
      items.each do |item|
        variant = variant_map[item['assortmentId']]
        next unless variant&.product
        
        update_station_feature(variant.product, station_name)
        stations_updated += 1
      end
    end
    
    stations_updated
  end

  def update_station_feature(product, station_name)
    return unless product.present? && station_name.present?
    
    property = Property.find_or_create_by!(title: 'Станция')
    characteristic = property.characteristics.find_or_create_by!(title: station_name)
    
    feature = product.features.find_or_initialize_by(property: property)
    feature.characteristic = characteristic
    feature.save!
  rescue StandardError => e
    Rails.logger.error "Moysklad::UpdateQuantitiesService: Error updating station feature for product #{product.id}: #{e.message}"
    nil
  end

  def authorization_header
    credentials = "#{@moysklad.api_key}:#{@moysklad.api_password}"
    'Basic ' + Base64.encode64(credentials).chomp
  end
  
  def create_email_delivery_and_notify(result, error_class = nil)
    subject = result[:success] ? 
      "✅ Обновление остатков из МойСклад - успешно" :
      "❌ Обновление остатков из МойСклад - ошибка"
    
    metadata = {
      moysklad_id: @moysklad.id,
      result: result[:success] ? 'success' : 'failed',
      details: {}
    }
    
    if result[:success]
      metadata[:details] = {
        updated_count: result[:updated_count],
        stations_updated: result[:stations_updated],
        with_quantity_count: result[:with_quantity_count],
        completed_at: Time.current.iso8601
      }
    else
      metadata[:details] = {
        error_class: error_class,
        error_message: result[:error],
        failed_at: Time.current.iso8601
      }
    end
    
    email_delivery = EmailDelivery.create!(
      recipient: @moysklad,
      record: nil,
      mailer_class: 'MoyskladNotificationMailer',
      mailer_method: 'update_quantities_result',
      recipient_email: NOTIFICATION_EMAIL,
      subject: subject,
      status: 'pending',
      metadata: metadata,
      error_message: result[:success] ? nil : result[:error]
    )
    
    # Отправляем email уведомление асинхронно
    MoyskladNotificationJob.perform_later(email_delivery.id)
  rescue StandardError => e
    Rails.logger.error "Moysklad::UpdateQuantitiesService: Error creating email delivery: #{e.class} - #{e.message}"
    # Не прерываем выполнение, если не удалось создать EmailDelivery
  end
end

