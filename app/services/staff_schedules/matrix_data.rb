module StaffSchedules
  # Shared loader for the staff schedule matrix (HTML and Excel export).
  class MatrixData
    attr_reader :month, :days, :employees, :matrix, :shift_codes

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
  end

end
