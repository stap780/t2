class Varbind < ApplicationRecord
  include ActionView::RecordIdentifier

  self.table_name = 'varbinds'

  belongs_to :record, polymorphic: true
  belongs_to :bindable, polymorphic: true
  
  validates :bindable_id, presence: true
  validates :bindable_type, presence: true
  validates :value, presence: true
  validate :value_unique_per_integration
  validate :record_has_single_binding_per_integration

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.int_types
    [['insales','Insale'],['avitos','Avito'],['moysklads','Moysklad']]
  end

  def self.int_ids
    base = []
    if defined?(Insale) && Insale.exists?
      base += Insale.all.map { |i| ["InSale #{i.id}", i.id] }
    end
    if defined?(Moysklad) && Moysklad.exists?
      base += Moysklad.all.map { |m| ["Moysklad #{m.id}", m.id] }
    end
    if defined?(Avito) && Avito.exists?
      base += Avito.all.map { |a| ["Avito #{a.id} (#{a.title})", a.id] }
    end
    base
  end

  private

  def value_unique_per_integration
    return if value.blank? || bindable_id.blank? || bindable_type.blank?

    scope = Varbind.where(bindable_id: bindable_id, bindable_type: bindable_type, value: value)
    scope = scope.where.not(id: id) if persisted?
    return unless scope.exists?

    other = scope.first
    entity = record_entity_label(other&.record_type)
    errors.add(:base, "ID #{value} уже привязан к другому #{entity} (#{other.record_type}##{other.record_id})")
  end

  def record_has_single_binding_per_integration
    return if record_id.blank? || record_type.blank? || bindable_id.blank? || bindable_type.blank?

    scope = Varbind.where(
      record_type: record_type,
      record_id: record_id,
      bindable_id: bindable_id,
      bindable_type: bindable_type
    )
    scope = scope.where.not(id: id) if persisted?
    return unless scope.exists?

    entity = record_entity_label(record_type)
    errors.add(:base, "у #{entity} может быть только одна привязка к данной интеграции")
  end

  def record_entity_label(type)
    type.to_s == "Product" ? "товару" : "варианту"
  end
end

