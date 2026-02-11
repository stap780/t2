class Variant < ApplicationRecord
  require 'barby'
  require 'barby/barcode/ean_13'
  require 'barby/outputter/html_outputter'
  require 'barby/outputter/ascii_outputter'
  require 'barby/outputter/png_outputter'
  require 'base64'

  include ActionView::RecordIdentifier
  include Bindable

  belongs_to :product
  
  audited associated_with: :product
  has_many :items
  has_one_attached :etiketka
  
  after_initialize :set_default_new, if: :new_record?
  after_commit :create_barcode, on: :create
  before_destroy :prevent_destroy_if_last

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :barcode, length: { minimum: 4, maximum: 13 }, allow_blank: true
  validates :barcode, uniqueness: { allow_blank: true }

  def broadcast_target_for_bindings
    [product, [self, :bindings]]
  end

  def broadcast_target_id_for_bindings
    dom_id(product, dom_id(self, :bindings))
  end

  def broadcast_locals_for_binding(binding)
    { record: self, varbind: binding }
  end

  def self.ransackable_attributes(auth_object = nil)
    Variant.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    ["bindings", "etiketka_attachment", "etiketka_blob", "list_items", "product", "items"]
  end

  # scopes for slimselect
  scope :for_slimselect, -> { order(:id).limit(8) }
  scope :selected, ->(id) { where(id: id) }

  def self.collection_for_select(id)
    collection = id.present? ? (selected(id) + for_slimselect).uniq : for_slimselect
    collection.map { |var| [var.full_title, var.id] }
  end

  def full_title
    # "#{barcode} - #{product.title} - #{sku}"
    # "#{barcode} - #{product.title}"
    "#{product.title}"
  end

  def title
    product.title.to_s
  end

  # Thread-safe cache for preloaded Detal records
  def self.preload_detals(detals_by_sku)
    Thread.current[:variant_preloaded_detals] = detals_by_sku
  end
  
  def self.clear_preloaded_detals
    Thread.current[:variant_preloaded_detals] = nil
  end

  # Получение oszz_price из Detal по SKU
  def oszz_price
    return nil if sku.blank?
    
    # Use preloaded Detal if available, otherwise fallback to database query
    preloaded_detals = Thread.current[:variant_preloaded_detals]
    if preloaded_detals && preloaded_detals.is_a?(Hash)
      # Preloaded data is a hash { sku => oszz_price }
      return preloaded_detals[sku]
    end
    
    # Fallback to database query if preloaded data not available
    @oszz_price ||= Detal.find_by(sku: sku)&.oszz_price
  end

  # Определение классов для подсветки цены на основе сравнения с oszz_price
  def price_with_danger?
    return false if price.blank? || oszz_price.blank?
    # Если цена товара значительно ниже oszz_price (более чем на 20%) - danger
    price < oszz_price * 0.8
  end

  def price_with_warning?
    return false if price.blank? || oszz_price.blank?
    # Если цена товара отличается от oszz_price на 10-20% - warning
    diff_percent = ((price - oszz_price) / oszz_price * 100).abs
    diff_percent >= 10 && diff_percent < 20
  end

  def price_css_classes
    classes = []
    classes << "bg-red-100" if price_with_danger?
    classes << "bg-yellow-100" if price_with_warning?
    classes.join(" ")
  end

  def relation?
    result = []
    # Проверяем наличие связанных list_items
    # if list_items.exists?
    #   result << 'list_items'
    # end
    result.count.zero? ? [false, ''] : [true, result]
  end

  # Возвращает последний item для этого варианта (для обратной совместимости)
  def item
    items.order(created_at: :desc).first
  end

  def create_barcode
    return if barcode.present?
  
    next_number = BarcodeCounter.next_value!
    code_value = next_number.to_s.rjust(12, '0')
    barcode_obj = Barby::EAN13.new(code_value)
    update_column(:barcode, barcode_obj.data_with_checksum)
    
    generate_etiketka
  end

  def generate_etiketka
    return unless barcode.present? && barcode.size == 13
    return if etiketka.attached? # Не пересоздаем, если уже есть

    success, blob = EtiketkaService.new(self).call
    
    if success && blob
      etiketka.attach(blob)
      Rails.logger.info "Etiketka attached to variant #{id}"
    else
      Rails.logger.error "Failed to generate etiketka for variant #{id}: #{blob.inspect}"
    end
  rescue => e
    Rails.logger.error "Error generating etiketka for variant #{id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def html_barcode
    return unless barcode&.size == 13

    barcode = Barby::EAN13.new(self.barcode[0...-1])
    barcode_for_html = Barby::HtmlOutputter.new(barcode)
    barcode_for_html.to_html.html_safe
  end

  def png_barcode
    return unless barcode&.size == 13

    barcode = Barby::EAN13.new(self.barcode[0...-1])
    barcode_png = Barby::PngOutputter.new(barcode)
    image_64 = barcode_png.to_png
    "<img src='data:image/png;base64,#{Base64.encode64(image_64)}'>".html_safe
  end

  private

  def set_default_new
    self.quantity = 0 if quantity.nil?
    self.price = 0 if price.nil?
  end

  def prevent_destroy_if_last
    # Не блокируем удаление, если продукт тоже удаляется
    # Когда продукт удаляется через dependent: :destroy, Rails сначала удаляет связанные записи
    # В этот момент продукт еще не помечен как destroyed, но находится в процессе удаления
    # 
    # Используем проверку через стек вызовов - если мы вызываемся из контекста удаления продукта,
    # то в стеке будет вызов через CollectionAssociation#delete_or_destroy
    caller_stack = caller.join("\n")
    
    # Проверяем, вызывается ли удаление варианта в контексте удаления продукта
    # Ищем паттерны, которые указывают на удаление через dependent: :destroy
    # Ключевой индикатор - наличие CollectionAssociation#delete_or_destroy в стеке
    is_product_destroying = caller_stack.include?('CollectionAssociation#delete_or_destroy') ||
                           caller_stack.include?('collection_association.rb') && caller_stack.include?('delete_or_destroy')
    
    # Если продукт удаляется, не блокируем удаление варианта
    if is_product_destroying
      Rails.logger.debug "[Variant#prevent_destroy_if_last] Skipping check - product is being destroyed"
      return
    end
    
    # Проверяем количество вариантов ПЕРЕД удалением текущего
    # Используем reload, чтобы получить актуальное количество вариантов
    variants_count = product.variants.reload.count
    
    # Если продукт имеет только один вариант и мы пытаемся его удалить напрямую (не через удаление продукта)
    # то блокируем удаление
    if variants_count <= 1
      Rails.logger.warn "[Variant#prevent_destroy_if_last] Blocking deletion - last variant for product #{product_id}"
      errors.add(:base, 'Cannot delete the last variant')
      throw(:abort)
    end
  end

end
