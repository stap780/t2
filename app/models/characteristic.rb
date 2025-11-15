class Characteristic < ApplicationRecord
  belongs_to :property
  has_many :features, dependent: :destroy
  has_many :products, through: :features

  validates :title, presence: true
  validates :title, uniqueness: { scope: :property_id }
end
