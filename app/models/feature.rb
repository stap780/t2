class Feature < ApplicationRecord
  belongs_to :product
  belongs_to :property
  belongs_to :characteristic

  validates :property_id, uniqueness: { scope: :product_id }
end
