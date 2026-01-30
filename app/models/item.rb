class Item < ApplicationRecord
  include NormalizeDataWhiteSpace
  
  belongs_to :incase
  belongs_to :item_status, optional: true
  belongs_to :variant, optional: true
  
  has_many :act_items, dependent: :destroy
  has_many :acts, through: :act_items
  
  audited associated_with: :incase
  
  validates :title, presence: true
  validates :quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  
  enum :condition, {
    priemka: 'priemka',
    utilizatsiya: 'utilizatsiya',
    otstoynik: 'otstoynik',
    remont: 'remont'
  }
  
  after_initialize :set_default_new
  before_create :set_default_status
  before_create :create_product_variant, if: -> { variant_id.blank? }
  after_save :recalculate_incase_status, if: :saved_change_to_item_status_id?
  after_destroy :recalculate_incase_status_after_destroy
  
  attribute :item_status_title
	
  def self.file_export_attributes
    # Базовый порядок: сначала название и статус, затем остальные поля
    attrs = attribute_names - %w[id incase_id item_status_id variant_id created_at updated_at]
    base  = %w[title item_status_title]

    # Сначала base в заданном порядке, затем все остальные атрибуты
    (base & attrs) + (attrs - base)
  end
  
  def self.ransackable_attributes(auth_object = nil)
    # Разрешаем поиск не только по колонкам, но и по вычисляемому атрибуту `barcode`,
    # который проксирует штрихкод варианта (variant.barcode). Это нужно, чтобы
    # работал фильтр `unumber_or_items_barcode_or_carnumber_cont` в убытках.
    super + %w[barcode]
  end

  # ransacker для поиска по штрихкоду варианта через items_barcode_*
  ransacker :barcode do |parent|
    # Используем подзапрос к variants.barcode, связанному по variant_id
    Arel.sql('(SELECT variants.barcode FROM variants WHERE variants.id = items.variant_id)')
  end

  def self.ransackable_associations(auth_object = nil)
    %w[incase item_status variant acts act_items]
  end

  def sum
    (quantity || 0) * (price || 0)
  end

  def barcode
    variant&.barcode
  end

  def last_status_change_date
    audit = Audited::Audit.where(
      auditable_type: 'Item',
      auditable_id: self.id
    )
    .where("audited_changes ? 'item_status_id'")
    .order(created_at: :desc)
    .first
    
    audit&.created_at || ''
  end

  def item_status_title
		return '' unless item_status.present?
		item_status.title
  end
  
  private
  
  def set_default_status
    return if item_status_id.present?
    
    # Устанавливаем статус "Не ездили" для новой детали, если статус не указан
    v_rabote_status = ItemStatus.find_by(title: 'В работе')
    self.item_status_id = v_rabote_status.id if v_rabote_status
  end

  def set_default_new
    self.quantity ||= 0 if new_record?
  end

  def create_product_variant
    return if variant_id.present?
    
    product = Product.create!(
      title: title.presence || 'Incase product',
      status: 'draft',
      tip: 'product'
    )
    variant = product.variants.create!(
      quantity: quantity || 0,
      price: price || 0,
      sku: katnumber.presence || ''
    )
    self.variant_id = variant.id
  end

  def recalculate_incase_status
    return unless incase_id.present?
    Incase.recalculate_status_from_items(incase_id)
    acts.each { |act| Act.recalculate_status_from_items(act) }
  end

  def recalculate_incase_status_after_destroy
    return unless incase_id.present?
    Incase.recalculate_status_from_items(incase_id)
  end


end

