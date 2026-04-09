class StaffSchedulesController < ApplicationController
  def index
    @schedule_days_count = ScheduleDay.count
    @employees_count = Employee.count
  end
end
