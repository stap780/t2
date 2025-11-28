class CompanyPlanDate < ApplicationRecord
  belongs_to :company
  has_many :comments, as: :commentable, dependent: :destroy
  accepts_nested_attributes_for :comments, allow_destroy: true

  validates :date, presence: true
end
