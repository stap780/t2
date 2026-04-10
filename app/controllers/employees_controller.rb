class EmployeesController < ApplicationController
  before_action :set_employee, only: %i[edit update destroy schedule]
  include ActionView::RecordIdentifier

  def index
    @employees = Employee.includes(:department, :manager, :user).order(:full_name)
  end

  def new
    @employee = Employee.new
  end

  def edit
  end

  def schedule
    @year = schedule_year_from_param
    range = Date.new(@year, 1, 1)..Date.new(@year, 12, 31)
    @shift_codes = ShiftCode.ordered
    @schedule_by_day = @employee.schedule_days.where(worked_on: range).includes(:shift_code).index_by(&:worked_on)
    @month_starts = (1..12).map { |m| Date.new(@year, m, 1) }
  end

  def create
    @employee = Employee.new(employee_params)

    respond_to do |format|
      if @employee.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          streams = []
          streams << turbo_stream.remove("employees_empty_placeholder") if Employee.one?
          streams += turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "employees",
              partial: "employees/employee",
              locals: { employee: @employee }
            )
          ]
          render turbo_stream: streams
        end
        format.html { redirect_to employees_path, notice: t(".success") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @employee.update(employee_params)
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@employee),
              partial: "employees/employee",
              locals: { employee: @employee }
            )
          ]
        end
        format.html { redirect_to employees_path, notice: t(".success") }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @employee.destroy!
    flash.now[:success] = t(".success")
    respond_to do |format|
      format.turbo_stream do
        streams = [turbo_stream.remove(dom_id(@employee))]
        streams << turbo_stream.append("employees", partial: "employees/empty_placeholder") if Employee.none?
        streams << render_turbo_flash
        render turbo_stream: streams
      end
      format.html { redirect_to employees_path, notice: t(".success") }
    end
  end

  private

  def set_employee
    @employee = Employee.find(params[:id])
  end

  def employee_params
    params.require(:employee).permit(:full_name, :department_id, :manager_id, :user_id)
  end

  def schedule_year_from_param
    y = params[:year].presence&.to_i
    if y.present? && y.between?(1900, 2100)
      y
    else
      Date.current.year
    end
  end
end
