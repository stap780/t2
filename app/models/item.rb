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
  before_create :create_product_variant, if: -> { variant_id.blank? }
  
  attribute :barcode, :string
  attribute :item_status_title
	
	def self.file_export_attributes
    attribute_names - ["id","incase_id","item_status_id","variant_id","created_at","updated_at"]
	end
  
  def self.ransackable_attributes(auth_object = nil)
    # attribute_names
    super + %w(barcode)
  end

  def self.ransackable_associations(auth_object = nil)
    %w[incase item_status variant]
  end

  # Ransacker for virtual barcode attribute that uses variant.barcode
  ransacker :barcode do |parent|
    variants_table = Arel::Table.new(:variants)
    # Reference the variant's barcode through the association
    # This requires variant to be joined in the query
    variants_table[:barcode]
  end

  def sum
    (quantity || 0) * (price || 0)
  end

  def barcode
    variant.barcode
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


end

