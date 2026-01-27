class ActItem < ApplicationRecord
  belongs_to :act
  belongs_to :item
  
  validates :act_id, uniqueness: { scope: :item_id }

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[act item]
  end
end

