require "caxlsx"

module StaffSchedules
  # Builds an .xlsx for the schedule matrix: grid sheet + legend sheet.
  class MatrixXlsxExport
    WEEKEND_BG = "FFF1F5F9"
    DEFAULT_FG = "FF111827"

    def initialize(matrix_data)
      @data = matrix_data
    end

    def call
      package = Axlsx::Package.new
      wb = package.workbook
      @styles = wb.styles
      @style_cache = build_style_cache

      wb.add_worksheet(name: sheet_name(I18n.t("staff_schedules.matrix.xlsx.sheet_matrix"))) do |sheet|
        add_matrix_sheet(sheet)
      end

      wb.add_worksheet(name: sheet_name(I18n.t("staff_schedules.matrix.xlsx.sheet_legend"))) do |sheet|
        add_legend_sheet(sheet)
      end

      package.to_stream.read
    end

    private

    def add_matrix_sheet(sheet)
      num_cols = 2 + @data.days.size
      last_col = excel_column_number_to_name(num_cols)
      title = I18n.l(@data.month, format: :month_year)

      sheet.add_row(
        [ title ] + Array.new(num_cols - 1, ""),
        style: Array.new(num_cols, @style_cache[:title])
      )
      sheet.merge_cells("A1:#{last_col}1")

      header = [
        I18n.t("staff_schedules.matrix.xlsx.col_name"),
        I18n.t("staff_schedules.matrix.xlsx.col_department")
      ] + @data.days.map(&:day)

      header_styles = [
        @style_cache[:header],
        @style_cache[:header]
      ] + @data.days.map { |d| weekend_day?(d) ? @style_cache[:header_weekend] : @style_cache[:header] }

      sheet.add_row header, style: header_styles

      @data.employees.each do |employee|
        row = @data.matrix[employee.id] || {}
        cells = [
          employee.full_name,
          employee.department&.name.to_s
        ]
        cell_styles = [
          @style_cache[:name_col],
          @style_cache[:name_col]
        ]

        @data.days.each do |day|
          sd = row[day]
          cells << cell_short_label(sd&.shift_code)
          cell_styles << matrix_cell_style(sd, day)
        end

        sheet.add_row cells, style: cell_styles
      end

      widths = [ 24, 18 ] + Array.new(@data.days.size, 4)
      sheet.column_widths(*widths)

      sheet.sheet_view.pane do |pane|
        pane.top_left_cell = "C3"
        pane.state = :frozen_split
        pane.x_split = 2
        pane.y_split = 2
        pane.active_pane = :bottom_right
      end
    end

    def add_legend_sheet(sheet)
      sheet.add_row [
        I18n.t("staff_schedules.matrix.xlsx.legend_code"),
        I18n.t("staff_schedules.matrix.xlsx.legend_label"),
        I18n.t("staff_schedules.matrix.xlsx.legend_color")
      ], style: [ @style_cache[:header], @style_cache[:header], @style_cache[:header] ]

      @data.shift_codes.each do |sc|
        fill = excel_argb(sc.color)
        swatch = fill ? @styles.add_style(bg_color: fill, fg_color: DEFAULT_FG) : @style_cache[:legend_empty]
        sheet.add_row [ sc.code, sc.label, "" ], style: [ @style_cache[:legend_text], @style_cache[:legend_text], swatch ]
      end

      sheet.column_widths 14, 28, 10
    end

    def cell_short_label(shift_code)
      return "" unless shift_code

      ActionController::Base.helpers.truncate(shift_code.label.to_s, length: 3, omission: "")
    end

    def matrix_cell_style(schedule_day, day)
      if schedule_day&.shift_code&.color.present?
        argb = excel_argb(schedule_day.shift_code.color)
        return shift_style(argb) if argb
      end
      return @style_cache[:weekend] if weekend_day?(day)

      nil
    end

    def shift_style(argb)
      @shift_styles[argb] ||= @styles.add_style(bg_color: argb, fg_color: DEFAULT_FG)
    end

    def weekend_day?(day)
      day.saturday? || day.sunday?
    end

    def build_style_cache
      @shift_styles = {}
      {
        title: @styles.add_style(b: true, sz: 14, bg_color: "FFFFFFFF", fg_color: DEFAULT_FG,
          alignment: { horizontal: :center }),
        header: @styles.add_style(b: true, bg_color: "FFF9FAFB", fg_color: DEFAULT_FG),
        header_weekend: @styles.add_style(b: true, bg_color: "FFE2E8F0", fg_color: DEFAULT_FG),
        name_col: @styles.add_style(bg_color: "FFFFFFFF", fg_color: DEFAULT_FG),
        legend_text: @styles.add_style(fg_color: DEFAULT_FG),
        legend_empty: @styles.add_style(bg_color: "FFF3F4F6", fg_color: DEFAULT_FG),
        weekend: @styles.add_style(bg_color: WEEKEND_BG, fg_color: DEFAULT_FG)
      }
    end

    def excel_argb(hex)
      s = hex.to_s.strip.delete_prefix("#")
      case s.length
      when 3
        s = s.chars.map { |c| c + c }.join
      when 6
        # ok
      else
        return nil
      end
      return nil unless s.match?(/\A[0-9a-fA-F]{6}\z/)

      "FF#{s.upcase}"
    end

    # Axlsx sheet name: max 31 chars, no : \ / ? * [ ]
    def sheet_name(title)
      title.to_s.tr(":*?/\\[]", "-")[0, 31]
    end

    # 1-based Excel column index: 1 → A, 26 → Z, 27 → AA
    def excel_column_number_to_name(n)
      s = +""
      while n.positive?
        n -= 1
        s = (65 + (n % 26)).chr + s
        n /= 26
      end
      s
    end
  end
end
