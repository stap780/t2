module StaffSchedulesHelper
  include ActionView::RecordIdentifier

  def schedule_cell_dom_id(employee, worked_on)
    dom_id(employee, "schedule_cell_#{worked_on.to_fs(:db)}")
  end

  # Ячейка сводной таблицы (отдельный id от schedule_cell_* для Turbo в том же ответе batch)
  def matrix_cell_dom_id(employee, worked_on)
    dom_id(employee, "matrix_cell_#{worked_on.to_fs(:db)}")
  end

  def schedule_cell_background_style(schedule_day, date)
    if schedule_day&.shift_code&.color.present?
      "background-color: #{schedule_day.shift_code.color};"
    elsif date.saturday? || date.sunday?
      "background-color: rgb(248 250 252);"
    else
      ""
    end
  end

  # Понедельник — первый столбец; nil — пустая ячейка до начала месяца
  def schedule_month_calendar_days(month_date)
    first = month_date.beginning_of_month
    last = month_date.end_of_month
    leading = first.cwday - 1
    days = Array.new(leading, nil)
    (first..last).each { |d| days << d }
    days
  end

  def staff_schedule_year_param(year)
    year.to_s
  end

  def staff_schedule_prev_year(year)
    year - 1
  end

  def staff_schedule_next_year(year)
    year + 1
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

  def staff_schedules_path_for_month(month_date)
    staff_schedules_path(month: staff_schedule_month_param(month_date))
  end

  def schedule_matrix_cell_style(schedule_day, date)
    if schedule_day&.shift_code&.color.present?
      "background-color: #{schedule_day.shift_code.color};"
    elsif date.saturday? || date.sunday?
      "background-color: rgb(248 250 252);"
    else
      ""
    end
  end
end
