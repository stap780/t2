class DepartmentsController < ApplicationController
  before_action :set_department, only: %i[edit update destroy]
  include ActionView::RecordIdentifier

  def index
    @departments = Department.order(:name)
  end

  def new
    @department = Department.new
  end

  def edit
  end

  def create
    @department = Department.new(department_params)

    respond_to do |format|
      if @department.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          streams = []
          streams << turbo_stream.remove("departments_empty_placeholder") if Department.one?
          streams += turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "departments",
              partial: "departments/department",
              locals: { department: @department }
            )
          ]
          render turbo_stream: streams
        end
        format.html { redirect_to departments_path, notice: t(".success") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @department.update(department_params)
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@department),
              partial: "departments/department",
              locals: { department: @department }
            )
          ]
        end
        format.html { redirect_to departments_path, notice: t(".success") }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @department.destroy!
    flash.now[:success] = t(".success")
    respond_to do |format|
      format.turbo_stream do
        streams = [turbo_stream.remove(dom_id(@department))]
        streams << turbo_stream.append("departments", partial: "departments/empty_placeholder") if Department.none?
        streams << render_turbo_flash
        render turbo_stream: streams
      end
      format.html { redirect_to departments_path, notice: t(".success") }
    end
  end

  private

  def set_department
    @department = Department.find(params[:id])
  end

  def department_params
    params.require(:department).permit(:name)
  end
end
