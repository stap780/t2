class Varbind < ApplicationRecord
  include ActionView::RecordIdentifier

  self.table_name = 'varbinds'

  belongs_to :record, polymorphic: true
  belongs_to :bindable, polymorphic: true
  
  validates :bindable_id, presence: true
  validates :bindable_type, presence: true
  validates :value, presence: true
  validates :value, uniqueness: {
    scope: [:bindable_id, :bindable_type],
    message: "этот ID %{value} уже привязан к другому варианту в данной интеграции"
  }
  validates :record_id, uniqueness: {
    scope: [:record_type, :bindable_id, :bindable_type],
    message: "у варианта может быть только одна привязка к данной интеграции"
  }

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.int_types
    [['insales','Insale'],['avitos','Avito'],['moysklads','Moysklad']]
  end

  def self.int_ids
    return [] unless defined?(Insale) && Insale.exists?
    Insale.all.map { |i| ["InSale #{i.id}", i.id] } + Moysklad.all.map { |m| ["Moysklad #{m.id}", m.id] }
    # Avito.all.map { |a| ["Avito #{a.id}", a.id] }
  end

  


end

