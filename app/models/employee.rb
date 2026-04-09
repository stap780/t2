class Employee < ApplicationRecord
  belongs_to :department, optional: true
  belongs_to :manager, class_name: "Employee", optional: true, inverse_of: :direct_reports
  belongs_to :user, optional: true

  has_many :direct_reports, class_name: "Employee", foreign_key: :manager_id, dependent: :nullify, inverse_of: :manager
  has_many :schedule_days, dependent: :destroy

  validates :full_name, presence: true

  scope :ordered, -> { order(:full_name) }
end
