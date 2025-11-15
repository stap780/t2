class Property < ApplicationRecord
  include ActionView::RecordIdentifier

  has_many :features, dependent: :destroy
  has_many :products, through: :features
  has_many :characteristics, dependent: :destroy
  accepts_nested_attributes_for :characteristics, allow_destroy: true, reject_if: :all_blank

  validates :title, presence: true, uniqueness: true


end
