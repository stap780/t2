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
  has_many :list_items, as: :item
  has_one_attached :etiketka
  
  after_initialize :set_default_new, if: :new_record?
  after_commit :create_barcode, on: :create
  before_destroy :prevent_destroy_if_last

  validates :quantity, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :barcode, length: { minimum: 8, maximum: 13 }, allow_blank: true
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

  def relation?
    result = []
    # Проверяем наличие связанных list_items
    # if list_items.exists?
    #   result << 'list_items'
    # end
    result.count.zero? ? [false, ''] : [true, result]
  end

  def create_barcode
    return if barcode.present?

    code_value = id.to_s.rjust(12, '0')
    barcode = Barby::EAN13.new(code_value)
    barcode.checksum
    update!(barcode: barcode.data_with_checksum)
    
    # Создаем этикетку сразу после создания баркода
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
