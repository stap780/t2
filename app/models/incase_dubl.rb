class IncaseDubl < ApplicationRecord
  include ActionView::RecordIdentifier
  
  belongs_to :incase_import
  belongs_to :strah, class_name: 'Company', foreign_key: 'strah_id', optional: true
  belongs_to :company, optional: true
  has_many :incase_item_dubls, dependent: :destroy
  
  def existing_incase
    Incase.find_by(unumber: unumber)
  end
  
  def differences
    return {} unless existing_incase
    
    {
      date: existing_incase.date != date,
      stoanumber: existing_incase.stoanumber != stoanumber,
      company_id: existing_incase.company_id != company_id,
      strah_id: existing_incase.strah_id != strah_id,
      carnumber: existing_incase.carnumber != carnumber,
      modelauto: existing_incase.modelauto != modelauto,
      region: existing_incase.region != region
    }
  end
  
  def has_differences?
    differences.values.any?
  end
  
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[incase_import strah company incase_item_dubls]
  end
end

