class Product < ApplicationRecord
  require 'barby'
  require 'barby/barcode/ean_13'
  require 'barby/outputter/html_outputter'

  include NormalizeDataWhiteSpace
  include Rails.application.routes.url_helpers
  include ActionView::RecordIdentifier
  include Bindable
  audited except: [:images_urls, :file_description]

  has_many :features, as: :featureable, dependent: :destroy
  has_many :properties, through: :features
  accepts_nested_attributes_for :features, allow_destroy: true

  has_many :variants, -> { order(id: :asc) }, dependent: :destroy
  accepts_nested_attributes_for :variants, allow_destroy: true

  has_rich_text :description

  has_many :images, -> { order(position: :asc) }, dependent: :destroy
  accepts_nested_attributes_for :images, allow_destroy: true

  has_associated_audits

  after_create_commit { broadcast_prepend_to 'products' }
  after_update_commit { broadcast_replace_to 'products' }
  after_destroy_commit { broadcast_remove_to 'products' }


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

  # Константы для статусов и типов
  STATUS = %w[draft pending in_progress active archived].freeze
  TIP = %w[product service kit].freeze

  # Ransack для поиска
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[associated_audits audits variants images properties features rich_text_description bindings varbinds]
  end

  def self.ransackable_scopes(auth_object = nil)
    %i[no_quantity yes_quantity all_quantity no_price yes_price with_images without_images]
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

  private


  def check_variants_have_items
    # Проверяем, есть ли Items, которые ссылаются на Variant этого Product
    variant_ids = variants.pluck(:id)
    return if variant_ids.empty?
    
    items_count = Item.where(variant_id: variant_ids).count
    if items_count > 0
      errors.add(:base, "Cannot delete product. There are #{items_count} item(s) that reference this product's variants.")
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

  
end
