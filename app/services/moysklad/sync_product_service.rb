require 'barby'
require 'barby/barcode/ean_13'
require 'rest-client'
require 'base64'
require 'json'

class Moysklad::SyncProductService
  def initialize(product, moysklad_config = nil)
    @product = product
    @variant = product.variants.first
    @moysklad = moysklad_config || Moysklad.first
    
    raise ArgumentError, "Product must have at least one variant" unless @variant
    raise ArgumentError, "Moysklad configuration not found" unless @moysklad
  end

  def call
    payload = build_payload
    send_to_moysklad(payload)
  end

  private

  def build_payload
    features_hash = @product.features_to_h
    
    {
      "name" => @product.title.to_s,
      "code" => code_for_payload,
      "externalCode" => @product.id.to_s,
      "description" => @product.file_description.to_s,
      "vat" => 18,
      "effectiveVat" => 18,
      "barcodes" => [barcode_for_payload],
      "salePrices" => [
        {
          "value" => price_in_cents,
          "priceType" => {
            "meta" => {
              "href" => "https://api.moysklad.ru/api/remap/1.2/context/companysettings/pricetype/309d4707-35fc-11e6-7a69-9711001fa0af",
              "type" => "pricetype",
              "mediaType" => "application/json"
            }
          }
        }
      ],
      "article" => @variant.sku.to_s,
      "attributes" => build_attributes,
      "isSerialTrackable" => false,
      "productFolder" => {
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/productfolder/770c8263-4dd9-11e7-7a34-5acf0005f710",
          "metadataHref" => "https://api.moysklad.ru/api/remap/1.2/entity/productfolder/metadata",
          "type" => "productfolder",
          "mediaType" => "application/json",
          "uuidHref" => "https://online.moysklad.ru/app/#good/edit?id=770c8263-4dd9-11e7-7a34-5acf0005f710"
        }
      }
    }
  end

  def code_for_payload
    # Используем sku, если есть, иначе barcode
    @variant.sku.present? ? @variant.sku : barcode_for_payload
  end

  def barcode_for_payload
    return @variant.barcode if @variant.barcode.present? && @variant.barcode.size == 13
    
    # Генерируем EAN13 из ID, если баркода нет
    code_value = @variant.id.to_s.rjust(12, '0')
    barcode = Barby::EAN13.new(code_value)
    barcode.checksum
    barcode.data_with_checksum
  end

  def price_in_cents
    return 0 if @variant.price.nil?
    (@variant.price * 100).to_f.round(0)
  end

  def build_attributes
    features_hash = @product.features_to_h
    
    # Базовые атрибуты (всегда присутствуют)
    base_attributes = [
      {
        "id" => "9d782847-3600-11e6-7a69-9711001fe78b",
        "name" => "Марка",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/9d782847-3600-11e6-7a69-9711001fe78b",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => extract_marka_model }
      },
      {
        "id" => "df49db12-279d-11ed-0a80-0e910034bd6c",
        "name" => "Наименование поставщика",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/df49db12-279d-11ed-0a80-0e910034bd6c",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => extract_supplier }
      }
    ]
    
    # Проверяем наличие "Тип диска" (dtype)
    if features_hash['Тип диска'].present?
      base_attributes += build_disk_attributes(features_hash)
    # Проверяем наличие "Диаметр, дюймы" (sdiameter)
    elsif features_hash['Диаметр, дюймы'].present?
      base_attributes += build_tire_attributes(features_hash)
    end
    
    base_attributes
  end

  def extract_marka_model
    features_hash = @product.features_to_h
    marka = features_hash['Марка'] || features_hash['Brand']
    model = features_hash['Модель'] || features_hash['Model']
    
    if marka.present? && model.present?
      "#{marka} #{model}"
    elsif marka.present?
      marka
    else
      'не указана'
    end
  end

  def extract_supplier
    # Поставщик - это компания, связанная с incase через company_id
    # Ищем через Item -> Incase -> Company
    item = Item.joins(:incase).where(variant_id: @variant.id).first
    if item&.incase&.company&.title.present?
      item.incase.company.title
    else
      'не нашли поставщика'
    end
  end

  def build_disk_attributes(features_hash)
    [
      {
        "id" => "9f7aaaff-5181-11e9-9107-5048000e8738",
        "name" => "Тип диска",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/9f7aaaff-5181-11e9-9107-5048000e8738",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['Тип диска'] }
      },
      {
        "id" => "a79e379f-5188-11e9-9ff4-34e8000ad2f5",
        "name" => "Диаметр (R)",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/a79e379f-5188-11e9-9ff4-34e8000ad2f5",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['Диаметр'] || '' }
      },
      {
        "id" => "c2120d05-5188-11e9-9ff4-34e8000a784d",
        "name" => "Ширина обода",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/c2120d05-5188-11e9-9ff4-34e8000a784d",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['Ширина обода'] || '' }
      },
      {
        "id" => "d4ce8886-5188-11e9-9ff4-34e8000ad3fa",
        "name" => "Количество отверстий",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/d4ce8886-5188-11e9-9ff4-34e8000ad3fa",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['К-во отверстий'] || '' }
      },
      {
        "id" => "e7afc536-5188-11e9-912f-f3d4000ac6f4",
        "name" => "Диаметр расположения отверстий",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/e7afc536-5188-11e9-912f-f3d4000ac6f4",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['Диаметр отверстий'] || '' }
      },
      {
        "id" => "43d38561-5189-11e9-912f-f3d4000e5d7a",
        "name" => "Вылет (ET)",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/43d38561-5189-11e9-912f-f3d4000e5d7a",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['Вылет'] || '' }
      },
      {
        "id" => "23e2f8f2-821b-11ea-0a80-004a001acd4f",
        "name" => "Ступица (DIA)",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/23e2f8f2-821b-11ea-0a80-004a001acd4f",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => features_hash['Ступица (DIA)'] || ''
      }
    ]
  end

  def build_tire_attributes(features_hash)
    [
      {
        "id" => "9898167d-f5fb-11eb-0a80-00a60011819c",
        "name" => "Диаметр шин",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/9898167d-f5fb-11eb-0a80-00a60011819c",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['Диаметр, дюймы'] || '' }
      },
      {
        "id" => "98981784-f5fb-11eb-0a80-00a60011819d",
        "name" => "Сезонность шин",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/98981784-f5fb-11eb-0a80-00a60011819d",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['Сезонность шин'] || '' }
      },
      {
        "id" => "9898187c-f5fb-11eb-0a80-00a60011819e",
        "name" => "Ширина профиля шин",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/9898187c-f5fb-11eb-0a80-00a60011819e",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['Ширина профиля шины'] || '' }
      },
      {
        "id" => "989812be-f5fb-11eb-0a80-00a60011819b",
        "name" => "Высота профиля шин",
        "meta" => {
          "href" => "https://api.moysklad.ru/api/remap/1.2/entity/product/metadata/attributes/989812be-f5fb-11eb-0a80-00a60011819b",
          "type" => "attributemetadata",
          "mediaType" => "application/json"
        },
        "value" => { "name" => features_hash['Высота профиля шины'] || '' }
      }
    ]
  end

  def send_to_moysklad(payload)
    uri = "https://api.moysklad.ru/api/remap/1.2/entity/product"
    auth = authorization_header
    
    Rails.logger.info "Moysklad::SyncProductService: Sending product ##{@product.id} to Moysklad"
    
    RestClient.post(uri, payload.to_json, Authorization: auth, content_type: 'json', accept: 'application/json') do |response, request, result|
      data = JSON.parse(response.body)
      
      case response.code
      when 200
        ms_id = data['id']
        create_varbind(ms_id)
        Rails.logger.info "Moysklad::SyncProductService: Product ##{@product.id} successfully synced, ms_id: #{ms_id}"
        { success: true, ms_id: ms_id }
      when 412
        Rails.logger.warn "Moysklad::SyncProductService: Product ##{@product.id} - error 412 (duplicate code): #{data.inspect}"
        { success: false, error_code: 412, error: "Duplicate code" }
      else
        Rails.logger.error "Moysklad::SyncProductService: Product ##{@product.id} - error #{response.code}: #{data.inspect}"
        { success: false, error_code: response.code, error: data['errors'] || data['error_message'] || 'Unknown error' }
      end
    end
  rescue RestClient::ExceptionWithResponse => e
    Rails.logger.error "Moysklad::SyncProductService: RestClient error for product ##{@product.id}: #{e.message}"
    { success: false, error: e.message }
  rescue StandardError => e
    Rails.logger.error "Moysklad::SyncProductService: Error for product ##{@product.id}: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end

  def authorization_header
    credentials = "#{@moysklad.api_key}:#{@moysklad.api_password}"
    'Basic ' + Base64.encode64(credentials).chomp
  end

  def create_varbind(ms_id)
    @product.bindings.find_or_create_by!(
      bindable: @moysklad,
      value: ms_id
    )
  end
  
end

