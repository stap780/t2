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
    @month = schedule_month_from_param
    start = @month.beginning_of_month
    finish = @month.end_of_month
    @days = (start..finish).to_a
    @shift_codes = ShiftCode.ordered
    @schedule_by_day = @employee.schedule_days.where(worked_on: start..finish).index_by(&:worked_on)
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

  def schedule_month_from_param
    if params[:month].present?
      Date.parse("#{params[:month]}-01")
    else
      Date.current.beginning_of_month
    end
  rescue ArgumentError
    Date.current.beginning_of_month
  end
end
