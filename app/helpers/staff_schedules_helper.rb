module StaffSchedulesHelper
  include ActionView::RecordIdentifier

  # Должен совпадать с id строки в ScheduleDaysController#schedule_row_dom_id
  def schedule_row_dom_id(employee, worked_on)
    dom_id(employee, "schedule_row_#{worked_on.to_fs(:db)}")
  end

  def staff_schedule_month_param(month)
    month.strftime("%Y-%m")
  end

  def staff_schedule_prev_month(month)
    month.prev_month.beginning_of_month
  end

  def staff_schedule_next_month(month)
    month.next_month.beginning_of_month
  end
end
