class Characteristic < ApplicationRecord
  belongs_to :property
  has_many :features, dependent: :destroy
  has_many :products, -> { where(features: { featureable_type: 'Product' }) }, through: :features, source: :featureable, source_type: 'Product'
  has_many :detal_features, -> { where(featureable_type: 'Detal') }, class_name: 'Feature'
  has_many :detals, through: :detal_features, source: :featureable, source_type: 'Detal'

  validates :title, presence: true
  validates :title, uniqueness: { scope: :property_id }

  scope :first_for_property, ->(property_id, limit = 50) do
    where(property_id: property_id).order(title: :asc).limit(limit)
  end

  # Для select/options_for_select: выбранное значение + первые N по алфавиту
  scope :collection_for_select, ->(property_id, selected_id = nil, limit = 50) do
    rel = where(property_id: property_id)

    selected =
      if selected_id.present?
        rel.where(id: selected_id)
      else
        none
      end

    top = rel.order(title: :asc).limit(limit)
    (selected.to_a + top.to_a).uniq(&:id).map { |c| [c.title, c.id] }
  end

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

end
