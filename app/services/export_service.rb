require "csv"
require "json"
require "zip"
require "stringio"
require "liquid"
require "caxlsx"

# ExportService inspired by Dizauto's ExportCreator
class ExportService
  def initialize(export)
    @export = export
  end

  def call
    Rails.logger.info "📤 ExportService: Starting export for Export ##{@export.id} (#{@export.test_mode? ? 'TEST' : 'PRODUCTION'} mode)"
    @export.update!(status: "processing")

    begin
      # Get filtered data based on selected headers
      data = collect_filtered_data

      if data.empty?
        raise "No data available for export. Import may be missing or incomplete."
      end

      # Log data information
      selected_headers_info = @export.file_headers&.any? ? " (#{@export.file_headers.length} selected fields)" : " (all fields)"
      if @export.test_mode?
        Rails.logger.info "📤 ExportService: TEST MODE - Processing #{data.length} records#{selected_headers_info} (limited to #{Export::TEST_LIMIT})"
      else
        Rails.logger.info "📤 ExportService: PRODUCTION MODE - Processing #{data.length} records#{selected_headers_info}"
      end

      # Create export file based on format (like Dizauto)
      result = case @export.format
      when "csv"
        create_csv
      when "xlsx"
        create_xlsx
      when "xml"
        create_xml
      else
        raise "Unsupported export format: #{@export.format}"
      end

      if result
        @export.update!(status: "completed", exported_at: Time.current)
        Rails.logger.info "📤 ExportService: Export completed successfully"
        [true, @export]
      else
        @export.update!(status: "failed", error_message: "Failed to create export file")
        [false, "Export creation failed"]
      end
    rescue => e
      Rails.logger.error "📤 ExportService ERROR: #{e.message}"
      Rails.logger.error "📤 ExportService ERROR: #{e.backtrace.join("\n")}"

      # Save error message to the export record
      @export.update!(
        status: "failed",
        error_message: "#{e.class.name}: #{e.message}"
      )

      [false, e.message]
    end
  end

  private

  def collect_filtered_data
    # Get source data from export
    source_data = @export.data
    return [] if source_data.empty?

    # If no specific headers are selected, return all data
    return source_data unless @export.file_headers&.any?

    Rails.logger.info "📤 ExportService: Filtering data to include only selected headers: #{@export.file_headers.join(', ')}"

    # Filter data to include only selected headers
    filtered_data = source_data.map do |record|
      filtered_record = {}
      @export.file_headers.each do |header|
        if record.key?(header)
          filtered_record[header] = record[header]
        else
          Rails.logger.warn "📤 ExportService: Header '#{header}' not found in source data"
          filtered_record[header] = nil
        end
      end
      filtered_record
    end

    Rails.logger.info "📤 ExportService: Filtered #{filtered_data.length} records to #{@export.file_headers.length} selected fields"
    filtered_data
  end

  def create_csv
    data = collect_filtered_data
    return false if data.empty?

    csv_content = CSV.generate do |csv|
      # Add headers from selected fields or first record
      headers = @export.file_headers&.any? ? @export.file_headers : data.first.keys
      csv << headers

      # Add data rows
      data.each do |record|
        csv << headers.map { |header| record[header] }
      end
    end

    attach_file(csv_content, "csv", "text/csv")
  end

  def create_xlsx
    data = collect_filtered_data
    return false if data.empty?

    # Create XLSX using Axlsx (like Dizauto)
    p = Axlsx::Package.new
    wb = p.workbook

    wb.add_worksheet(name: "Sheet 1") do |sheet|
      # Add headers from selected fields or first record
      headers = @export.file_headers&.any? ? @export.file_headers : data.first.keys
      sheet.add_row headers

      data.each do |record|
        sheet.add_row headers.map { |header| record[header] }
      end
    end

    # Generate XLSX content
    stream = p.to_stream
    xlsx_content = stream.read

    attach_file(xlsx_content, "xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
  end

  def create_xml
    return false, "XML template is required" unless @export.template.present?
    
    # Use Liquid template (like Dizauto)
    template = Liquid::Template.parse(@export.template)
    export_drop = Drop::Export.new(@export)
    xml_content = template.render("export" => export_drop)

    attach_file(xml_content, "xml", "application/xml")
  end

  def attach_file(content, format, content_type)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "export_#{@export.id}_#{timestamp}.#{format}"

    @export.export_file.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: content_type
    )

    true
  end
end
