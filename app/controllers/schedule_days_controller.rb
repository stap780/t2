class ScheduleDaysController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :set_employee, only: [:batch]

  def batch
    year = schedule_days_params[:year].present? ? schedule_days_params[:year].to_i : Date.current.year
    dates = parse_worked_on_dates(Array(schedule_days_params[:worked_on]))

    return respond_batch_error(@employee, year, t(".select_dates")) if dates.empty?

    clear = ActiveModel::Type::Boolean.new.cast(schedule_days_params[:clear])
    shift_code_id = schedule_days_params[:shift_code_id].presence

    if clear
      @employee.schedule_days.where(worked_on: dates).delete_all
    elsif shift_code_id.present?
      shift_code = ShiftCode.find(shift_code_id)
      ScheduleDay.transaction do
        dates.each do |date|
          sd = @employee.schedule_days.find_or_initialize_by(worked_on: date)
          sd.shift_code = shift_code
          sd.save!
        end
      end
    else
      return respond_batch_error(@employee, year, t(".pick_action"))
    end

    flash.now[:success] = t(".success")
    respond_to do |format|
      format.turbo_stream do
        streams = dates.uniq.sort.flat_map do |date|
          sd = @employee.schedule_days.find_by(worked_on: date)
          [
            turbo_stream.replace(
              schedule_cell_dom_id(@employee, date),
              partial: "employees/schedule_day_cell",
              locals: { employee: @employee, date: date, schedule_day: sd }
            ),
            turbo_stream.replace(
              matrix_cell_dom_id(@employee, date),
              partial: "staff_schedules/matrix_day_cell",
              locals: { employee: @employee, day: date, schedule_day: sd }
            )
          ]
        end
        streams << render_turbo_flash
        render turbo_stream: streams
      end
      format.html do
        redirect_to schedule_employee_path(@employee, year: year), notice: t(".success")
      end
    end
  end

  private

  def set_employee
    @employee = Employee.find(params.require(:employee_id))
  end

  def schedule_days_params
    @schedule_days_params ||= params.require(:schedule_days).permit(:shift_code_id, :year, :clear, worked_on: [])
  end

  def parse_worked_on_dates(values)
    values.filter_map do |raw|
      Date.parse(raw.to_s)
    rescue ArgumentError
      nil
    end
  end

  def schedule_cell_dom_id(employee, worked_on)
    dom_id(employee, "schedule_cell_#{worked_on.to_fs(:db)}")
  end

  def matrix_cell_dom_id(employee, worked_on)
    dom_id(employee, "matrix_cell_#{worked_on.to_fs(:db)}")
  end

  def respond_batch_error(employee, year, message)
    flash.now[:alert] = message
    respond_to do |format|
      format.turbo_stream { render turbo_stream: [render_turbo_flash], status: :unprocessable_entity }
      format.html do
        redirect_to schedule_employee_path(employee, year: year), alert: message
      end
    end
  end
end
