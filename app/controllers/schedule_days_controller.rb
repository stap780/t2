class ScheduleDaysController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_schedule_day, only: %i[update destroy]

  def create
    @schedule_day = ScheduleDay.new(schedule_day_params)
    @month = month_from_param

    if @schedule_day.save
      respond_with_success(@schedule_day)
    else
      employee = Employee.find(schedule_day_params[:employee_id])
      worked_on = parse_worked_on(schedule_day_params[:worked_on])
      respond_with_error(employee, worked_on, @schedule_day.errors.full_messages.to_sentence)
    end
  end

  def update
    @month = month_from_param

    if @schedule_day.update(schedule_day_update_params)
      respond_with_success(@schedule_day)
    else
      respond_with_error(@schedule_day.employee, @schedule_day.worked_on, @schedule_day.errors.full_messages.to_sentence)
    end
  end

  def destroy
    @month = month_from_param
    employee = @schedule_day.employee
    worked_on = @schedule_day.worked_on
    @schedule_day.destroy!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          schedule_row_dom_id(employee, worked_on),
          partial: "employees/schedule_day_row",
          locals: schedule_row_locals(employee, worked_on, nil)
        )
      end
      format.html { redirect_to schedule_employee_path(employee, month: @month.strftime("%Y-%m")) }
    end
  end

  private

  def set_schedule_day
    @schedule_day = ScheduleDay.find(params[:id])
  end

  def month_from_param
    if params[:month].present?
      Date.parse("#{params[:month]}-01")
    else
      Date.current.beginning_of_month
    end
  rescue ArgumentError
    Date.current.beginning_of_month
  end

  def parse_worked_on(value)
    value.is_a?(Date) ? value : Date.parse(value.to_s)
  end

  def schedule_day_params
    params.require(:schedule_day).permit(:employee_id, :worked_on, :shift_code_id)
  end

  def schedule_day_update_params
    params.require(:schedule_day).permit(:shift_code_id)
  end

  def schedule_row_dom_id(employee, worked_on)
    dom_id(employee, "schedule_row_#{worked_on.to_fs(:db)}")
  end

  def schedule_row_locals(employee, worked_on, schedule_day)
    {
      employee: employee,
      worked_on: worked_on,
      schedule_day: schedule_day,
      month: @month,
      shift_codes: ShiftCode.ordered
    }
  end

  def respond_with_success(schedule_day)
    employee = schedule_day.employee
    worked_on = schedule_day.worked_on
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          schedule_row_dom_id(employee, worked_on),
          partial: "employees/schedule_day_row",
          locals: schedule_row_locals(employee, worked_on, schedule_day)
        )
      end
      format.html { redirect_to schedule_employee_path(employee, month: @month.strftime("%Y-%m")) }
    end
  end

  def respond_with_error(employee, worked_on, message)
    flash.now[:alert] = message
    sd = ScheduleDay.find_by(employee_id: employee.id, worked_on: worked_on)
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(
            schedule_row_dom_id(employee, worked_on),
            partial: "employees/schedule_day_row",
            locals: schedule_row_locals(employee, worked_on, sd)
          ),
          turbo_stream.replace("flash", partial: "shared/flash")
        ]
      end
      format.html { redirect_to schedule_employee_path(employee, month: @month.strftime("%Y-%m")), alert: message }
    end
  end
end
