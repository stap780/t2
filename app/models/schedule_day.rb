class ScheduleDay < ApplicationRecord
  belongs_to :employee
  belongs_to :shift_code

  validates :worked_on, presence: true
  validates :employee_id, uniqueness: { scope: :worked_on }
end
