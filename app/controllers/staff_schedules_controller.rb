class StaffSchedulesController < ApplicationController
  def index
    @schedule_days_count = ScheduleDay.count
    @employees_count = Employee.count
    assign_matrix StaffSchedules::MatrixData.new(month_param: params[:month]).call
  end

  def export
    data = StaffSchedules::MatrixData.new(month_param: params[:month]).call
    xlsx = StaffSchedules::MatrixXlsxExport.new(data).call
    filename = "rab_graf_#{data.month.strftime('%Y-%m')}.xlsx"
    send_data xlsx,
      filename: filename,
      type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
      disposition: "attachment"
  end

  private

    def assign_matrix(data)
      @month = data.month
      @days = data.days
      @employees = data.employees.ordered
      @matrix = data.matrix
      @shift_codes = data.shift_codes
      @vacation_days_by_employee_id = data.vacation_days_by_employee_id
    end
end
