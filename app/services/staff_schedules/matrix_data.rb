module StaffSchedules
  # Shared loader for the staff schedule matrix (HTML and Excel export).
  class MatrixData
    attr_reader :month, :days, :employees, :matrix, :shift_codes, :vacation_days_by_employee_id

    def initialize(month_param: nil)
      @month_param = month_param
    end

    def load
      @month = parse_month(@month_param)
      range = @month.beginning_of_month..@month.end_of_month
      @days = range.to_a
      @employees = Employee.ordered.includes(:department)
      ids = @employees.map(&:id)
      @matrix = {}
      if ids.any?
        ScheduleDay.where(employee_id: ids, worked_on: range).includes(:shift_code).each do |sd|
          (@matrix[sd.employee_id] ||= {})[sd.worked_on] = sd
        end
      end
      @shift_codes = ShiftCode.ordered.to_a
      @vacation_days_by_employee_id = vacation_days_counts_for_year(ids, @month.year)
      self
    end

    alias_method :call, :load

    private

    def parse_month(param)
      if param.present?
        Date.parse("#{param}-01")
      else
        Date.current.beginning_of_month
      end
    rescue ArgumentError
      Date.current.beginning_of_month
    end

    def vacation_days_counts_for_year(employee_ids, year)
      return {} if employee_ids.empty?

      year_range = Date.new(year, 1, 1)..Date.new(year, 12, 31)
      ScheduleDay.joins(:shift_code)
        .where(employee_id: employee_ids, worked_on: year_range, shift_codes: { vacation: true })
        .group(:employee_id)
        .count
    end
  end
end
