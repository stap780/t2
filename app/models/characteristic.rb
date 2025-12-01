class Characteristic < ApplicationRecord
  belongs_to :property
  has_many :features, dependent: :destroy
  has_many :products, -> { where(features: { featureable_type: 'Product' }) }, through: :features, source: :featureable, source_type: 'Product'
  has_many :detal_features, -> { where(featureable_type: 'Detal') }, class_name: 'Feature'
  has_many :detals, through: :detal_features, source: :featureable, source_type: 'Detal'

  validates :title, presence: true
  validates :title, uniqueness: { scope: :property_id }

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

end
