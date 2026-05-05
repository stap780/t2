class Product < ApplicationRecord
  require 'barby'
  require 'barby/barcode/ean_13'
  require 'barby/outputter/html_outputter'

  include NormalizeDataWhiteSpace
  include Rails.application.routes.url_helpers
  include ActionView::RecordIdentifier
  include Bindable
  audited except: [:images_urls, :file_description]

  has_many :features, -> { order(:property_id) }, as: :featureable, dependent: :destroy
  has_many :properties, through: :features
  accepts_nested_attributes_for :features, allow_destroy: true

  has_many :variants, -> { order(id: :asc) }, dependent: :destroy
  accepts_nested_attributes_for :variants, allow_destroy: true

  has_rich_text :description

  has_many :images, -> { order(position: :asc) }, dependent: :destroy
  accepts_nested_attributes_for :images, allow_destroy: true

  has_associated_audits

  # after_create_commit { broadcast_prepend_to 'products' }
  after_update_commit { broadcast_replace_to 'products' }
  after_destroy_commit { broadcast_remove_to 'products' }

  after_create_commit :pull_product_from_detals
  after_update :sync_product_data_to_detals
  before_destroy :check_variants_have_items, prepend: true

  validates :title, presence: true

  attribute :images_urls
  attribute :file_description

  # Scopes для фильтрации
  scope :active, -> { where(status: 'active') }
  scope :draft, -> { where(status: 'draft') }
  scope :in_progress, -> { where(status: 'in_progress') }
  scope :archived, -> { where(status: 'archived') }

  scope :tip_product, -> { where(tip: 'product') }
  scope :tip_service, -> { where(tip: 'service') }
  scope :tip_kit, -> { where(tip: 'kit') }

  scope :include_images, -> { includes(images: %i[file_attachment file_blob]) }
  scope :include_features, -> { includes(:features) }

  scope :all_quantity, -> { ransack(variants_quantity_gteq: 0).result }
  scope :no_quantity, -> { ransack(variants_quantity_lt: 1).result }
  scope :yes_quantity, -> { ransack(variants_quantity_gt: 0).result }
  scope :no_price, -> { ransack(variants_price_lt: 1).result }
  scope :yes_price, -> { ransack(variants_price_gt: 0).result }

  scope :with_images, -> { joins(:images).where.not(images: {product_id: nil}).distinct }
  scope :without_images, -> { left_joins(:images).where(images: {product_id: nil}) }

  scope :with_insale, -> {
    joins(variants: :bindings).where(varbinds: { bindable_type: 'Insale' }).distinct
  }
  scope :with_moysklad, -> {
    joins(variants: :bindings).where(varbinds: { bindable_type: 'Moysklad' }).distinct
  }
  scope :without_insale, -> {
    where.not(id: joins(variants: :bindings).where(varbinds: { bindable_type: 'Insale' }).select(:id))
  }
  scope :without_moysklad, -> {
    where.not(id: joins(variants: :bindings).where(varbinds: { bindable_type: 'Moysklad' }).select(:id))
  }

  # Scopes для фильтрации по опасным/предупреждающим ценам
  scope :danger_true, -> { 
    joins(:variants)
      .joins("LEFT JOIN detals ON detals.sku = variants.sku")
      .where("variants.price IS NOT NULL")
      .where("detals.oszz_price IS NOT NULL")
      .where("variants.price < detals.oszz_price * 0.8")
      .distinct
  }

  scope :warning_true, -> {
    joins(:variants)
      .joins("LEFT JOIN detals ON detals.sku = variants.sku")
      .where("variants.price IS NOT NULL")
      .where("detals.oszz_price IS NOT NULL")
      .where("ABS((variants.price - detals.oszz_price) / detals.oszz_price * 100) >= 10")
      .where("ABS((variants.price - detals.oszz_price) / detals.oszz_price * 100) < 20")
      .distinct
  }

  # Константы для статусов и типов
  STATUS = %w[draft pending in_progress active archived].freeze
  TIP = %w[product service kit].freeze

  # Ключи audited_changes для фильтра по истории (прямые и связанные аудиты товара)
  AUDIT_CHANGE_KEYS = [
    ["Цена", "price"],
    ["Название", "title"],
    ["Статус", "status"],
  ].freeze

  AUTOFILL_SKIP_PROPERTY_TITLES = [
    'Категория товара',
    'Гарантия',
    'Видео',
    'Старый ID'
  ].freeze
  PRODUCT_LOCAL_FEATURE_DEFAULT_VALUE = 'fake'

  # Ransack для поиска
  def self.ransackable_attributes(auth_object = nil)
    attribute_names + %w[acts_number]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[associated_audits audits variants images properties features rich_text_description bindings varbinds]
  end

  def self.ransackable_scopes(auth_object = nil)
    %i[no_quantity yes_quantity all_quantity no_price yes_price with_images without_images with_insale with_moysklad without_insale without_moysklad danger_true warning_true]
  end

  # Ransacker для фильтрации по номеру акта через variants -> items -> acts
  ransacker :acts_number do |parent|
    Arel.sql("(
      SELECT string_agg(DISTINCT acts.number::text, ', ')
      FROM variants
      INNER JOIN items ON items.variant_id = variants.id
      INNER JOIN act_items ON act_items.item_id = items.id
      INNER JOIN acts ON acts.id = act_items.act_id
      WHERE variants.product_id = products.id
    )")
  end

  # Bindable methods
  def broadcast_target_for_bindings
    [self, :bindings]
  end

  def broadcast_target_id_for_bindings
    dom_id(self, :bindings)
  end

  def broadcast_locals_for_binding(binding)
    { record: self, varbind: binding }
  end

  # Helper методы для получения данных из первого варианта
  def var_sku
    return '' unless variants.present?
    variants.first.sku
  end

  def var_barcode
    return '' unless variants.present?
    variants.first.barcode
  end

  def var_price
    return '' unless variants.present?
    variants.first.price
  end

  def has_moysklad_binding?
    moysklad = Moysklad.first
    return false unless moysklad

    first_variant = variants.first
    return false unless first_variant

    first_variant.bindings.exists?(bindable: moysklad)
  end

  def has_insale_binding?
    insale = Insale.first
    return false unless insale

    bindings.exists?(bindable: insale) ||
      variants.joins(:bindings).where(varbinds: { bindable_type: 'Insale' }).exists?
  end

  def integration_links
    ProductIntegrationLinks.new(self).call
  end

  # Данные свойств для экспорта
  def properties_data 
    # this is for export csv/excel
    features.map { |feature| {feature.property.title.to_s => feature.characteristic.title.to_s} }
  end

  def features_to_h
    hash = {}
    features.each do |feature|
      hash[feature.property.title.to_s] = feature.characteristic.title.to_s
    end
    hash
  end

  def to_liquid
    @drop ||= Drop::Product.new(self) if defined?(Drop::Product)
  end

  # Работа с изображениями
  def image_first
    return nil unless images.present?

    image = images.first
    (image.file.attached? && image.file_blob.service.exist?(image.file_blob.key)) ? image.file : nil
  end

  def image_urls
    host = Rails.env.development? ? 'http://localhost:3000' : 'https://cpt.dizauto.ru'
    images.map do |image|
      host + rails_blob_path(image.file, only_path: true) if image.file.attached?
    end
  end

  # this is for attribute :images_urls
  def images_urls
    return [] unless images.present?
    images.map(&:s3_url)
  end

  # this is for attribute :file_description
  def file_description
    return '' unless description.present?
    description&.to_plain_text
  end

  # Навигация между продуктами
  def next
    Product.where('id > ?', id).order(id: :asc).first || Product.first
  end

  def previous
    Product.where('id < ?', id).order(id: :desc).first || Product.last
  end

  def stantsiya
    feature = features.find { |f| f.property.handle == 'stantsiya' }

    return '' unless feature.present?
    feature.characteristic&.title
  end

  def download_images
    blobs = images.filter_map do |img|
      img.file.blob if img.file.attached?
    end
    return nil if blobs.empty?

    zip_buffer = StringIO.new
    Zip::OutputStream.write_buffer(zip_buffer) do |zip|
      blobs.each_with_index do |blob, idx|
        ext = blob.filename.extension.presence || 'jpg'
        zip.put_next_entry("image_#{idx + 1}.#{ext}")
        zip.write(blob.download)
      end
    end
    zip_buffer.rewind
    zip_buffer.read
  end

  private

  def check_variants_have_items
    # Проверяем, есть ли позиции убытка (Item), которые ссылаются на Variant этого Product
    variant_ids = variants.pluck(:id)
    return if variant_ids.empty?
    
    items_count = Item.where(variant_id: variant_ids).count
    if items_count > 0
      errors.add(:base, I18n.t('activerecord.errors.models.product.variants_have_items', count: items_count))
      throw(:abort)
    end
  end

  def check_variants_have_relations
    if variants.size.positive?
      variants.each do |var|
        if var.respond_to?(:relation?)
          success, models = var.relation?
          if success
            models.each do |model|
              text = "Cannot delete. You have #{I18n.t(model)} with it."
              errors.add(:base, text)
            end
          end
        end
      end
    end

    return unless errors.present?

    errors.add(:base, 'Cannot delete product')
    throw(:abort)
  end

  # Синхронизация с InSales API
  def insale_api_update
    return [false, ["No Insale model"]] unless defined?(Insale)
    
    insale = Insale.first
    return [false, ["No Insale configuration"]] unless insale

    ok, msg = insale.api_work?
    return [false, Array(msg)] unless ok

    # External id for this product in Insale stored in Varbind
    external_id = bindings.find_by(bindable: insale)&.value
    return [false, ["No Insale binding value for product"]] if external_id.to_s.strip.blank?

    begin
      insale.api_init
      # Try to fetch product by id from Insales API
      ins_product = InsalesApi::Product.find(external_id)
    rescue StandardError => e
      Rails.logger.error("Product#insale_api_update fetch error: #{e.class} #{e.message}")
      return [false, ["Fetch error: #{e.message}"]]
    end

    # Map product fields defensively
    new_title = ins_product.try(:title)
    images = Array(ins_product.try(:images))
    first_image_url = images&.first.try(:large_url) rescue nil

    self.title = new_title.presence || title
    save! if changed?

    # Extract first variant payload from Insales and resolve local Variant by binding
    ins_variant = Array(ins_product.try(:variants)).first
    ext_variant_id = ins_variant.try(:id).to_s.presence

    # Find or create variant via binding (scoped to integration)
    variant = nil
    if ext_variant_id
      # First try to find existing variant by binding
      bnd = Varbind.find_by(bindable: insale, record_type: "Variant", value: ext_variant_id)
      variant = bnd&.record

      # If no variant found, create one and then create the binding
      unless variant
        variant = variants.create!
        Varbind.create!(record: variant, bindable: insale, value: ext_variant_id)
      end
    end

    update_attrs = {}
    update_attrs[:barcode]   = ins_variant.try(:barcode)
    update_attrs[:sku]       = ins_variant.try(:sku)
    update_attrs[:price]     = ins_variant.try(:price)
    variant.update!(update_attrs) if variant

    [true, { product: self, variant: variant }]
  end

  def pull_product_from_detals
    sku = variants.where.not(sku: [nil, '']).pick(:sku)
    return if sku.blank?

    detal = Detal.find_by(sku: sku)
    return unless detal

    self.title = detal.title if detal.title.present?

    if detal.desc.present?
      self.description = detal.desc
    end

    local_property_ids = product_local_property_ids
    features_scope = local_property_ids.any? ? features.where.not(property_id: local_property_ids) : features
    features_scope.destroy_all

    detal_features_scope = local_property_ids.any? ? detal.features.where.not(property_id: local_property_ids) : detal.features
    detal_features_scope.find_each do |df|
      features.build(property_id: df.property_id, characteristic_id: df.characteristic_id)
    end

    ensure_product_local_fake_features
    save!
  end

  def sync_product_data_to_detals
    skus = variants.where.not(sku: [nil, '']).pluck(:sku).uniq
    return if skus.empty?

    # Создаём Detal для SKU, если ещё нет
    skus.each do |sku|
      Detal.find_or_create_by!(sku: sku) { |detal| detal.title = title.presence || sku }
    end

    new_title = title
    new_desc = description.present? ? description.to_plain_text : nil
    local_property_ids = product_local_property_ids
    product_features = features.reload.where.not(property_id: local_property_ids).to_a

    Detal.where(sku: skus).find_each do |detal|
      attrs = {}
      attrs[:title] = new_title if detal.title != new_title
      attrs[:desc] = new_desc if new_desc.present? && detal.desc != new_desc

      detal.update_columns(attrs) if attrs.any?

      # Синхронизация параметров (features): заменяем параметры детали на параметры товара
      detal.features.destroy_all
      product_features.each do |pf|
        detal.features.create!(property_id: pf.property_id, characteristic_id: pf.characteristic_id)
      end
    end
  end

  def product_local_property_ids
    Property.where(title: AUTOFILL_SKIP_PROPERTY_TITLES).pluck(:id)
  end

  def ensure_product_local_fake_features
    AUTOFILL_SKIP_PROPERTY_TITLES.each do |property_title|
      property = Property.find_or_create_by!(title: property_title)
      feature = features.find_or_initialize_by(property: property)
      next if feature.characteristic_id.present?

      feature.characteristic = property.characteristics.find_or_create_by!(title: PRODUCT_LOCAL_FEATURE_DEFAULT_VALUE)
    end
  end

end
