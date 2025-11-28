class IncaseItemDubl < ApplicationRecord
  belongs_to :incase_dubl
  
  validates :title, presence: true
  
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end
  
  def self.ransackable_associations(auth_object = nil)
    ['incase_dubl']
  end
end

