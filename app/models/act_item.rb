class ActItem < ApplicationRecord
  belongs_to :act
  belongs_to :item
  
  validates :act_id, uniqueness: { scope: :item_id }
end

