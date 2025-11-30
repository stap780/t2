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
    message: "combination of Bindable Type, Bindable, and Value must be unique for this record" 
  }

  def self.int_types
    [['insales','Insale'],['avitos','Avito'],['moysklads','Moysklad']]
  end

  def self.int_ids
    return [] unless defined?(Insale) && Insale.exists?
    Insale.all.map { |i| ["InSale #{i.id}", i.id] } + Moysklad.all.map { |m| ["Moysklad #{m.id}", m.id] }
    # Avito.all.map { |a| ["Avito #{a.id}", a.id] }
  end

  private


end

