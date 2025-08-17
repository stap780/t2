class ImportSchedulesController < ApplicationController
  before_action :set_schedule, only: [:edit, :update, :destroy, :run]

  def index
    @import_schedules = ImportSchedule.order(created_at: :desc).includes(:user)
  end

  def new
    @import_schedule = current_user_schedule
  end

  def create
    @import_schedule = current_user_schedule(schedule_params)
    if @import_schedule.save
      redirect_to import_schedules_path, notice: "Schedule created"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @import_schedule.update(schedule_params)
      redirect_to import_schedules_path, notice: "Schedule updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @import_schedule.destroy
    redirect_to import_schedules_path, notice: "Schedule removed"
  end

  def run
    # fire immediately regardless of time
    ImportScheduleJob.perform_later(@import_schedule)
    redirect_to imports_path, notice: "Run queued"
  end

  private

  def set_schedule
    @import_schedule = ImportSchedule.find(params[:id])
  end

  def schedule_params
    params.require(:import_schedule).permit(:name, :time, :recurrence, :active)
  end

  def current_user_schedule(attrs = {})
    (Current.user || User.first).import_schedules.build(attrs)
  end
end
