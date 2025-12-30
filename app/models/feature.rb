class Feature < ApplicationRecord
  belongs_to :featureable, polymorphic: true
  belongs_to :property
  belongs_to :characteristic

  validates :property_id, uniqueness: { scope: [:featureable_type, :featureable_id] }
  
  # Отслеживание изменений для Product через associated_audits
  audited associated_with: :featureable
  
end