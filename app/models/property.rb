class Property < ApplicationRecord
  include ActionView::RecordIdentifier

  has_many :features, dependent: :destroy
  has_many :products, -> { where(features: { featureable_type: 'Product' }) }, through: :features, source: :featureable, source_type: 'Product'
  has_many :detal_features, -> { where(featureable_type: 'Detal') }, class_name: 'Feature'
  has_many :detals, through: :detal_features, source: :featureable, source_type: 'Detal'
  has_many :characteristics, dependent: :destroy
  accepts_nested_attributes_for :characteristics, allow_destroy: true, reject_if: :all_blank

  validates :title, presence: true, uniqueness: true


end
