require 'net/http'
require 'uri'
require 'zip'
require 'stringio'

class ImportService
  CSV_URL = 'http://138.197.52.153/exports/products.csv'
  
  def initialize(import)
    @import = import
  end
  
  def call
    Rails.logger.info "📥 ImportService: Starting import for Import ##{@import.id}"
    @import.update!(status: 'processing')

    begin
      Rails.logger.info "📥 ImportService: Downloading CSV from #{CSV_URL}"
      # Download CSV file
      csv_content = download_csv
      Rails.logger.info "📥 ImportService: Downloaded #{csv_content.length} bytes"

      Rails.logger.info "📥 ImportService: Extracting file headers"
      # Extract file headers from CSV content
      headers = extract_headers(csv_content)

      Rails.logger.info "📥 ImportService: Creating ZIP file"
      # Create zip file in memory and attach it
      zip_data = create_zip_file(csv_content)
      Rails.logger.info "📥 ImportService: ZIP file created (#{zip_data.length} bytes)"

      # Attach the ZIP file to the import using Active Storage
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      zip_filename = "import_#{@import.id}_#{timestamp}.zip"

      @import.zip_file.attach(
        io: StringIO.new(zip_data),
        filename: zip_filename,
        content_type: 'application/zip'
      )

      # Update import record with headers and completion status
      @import.update!(
        status: 'completed',
        imported_at: Time.current,
        file_header: headers
      )

      Rails.logger.info "📥 ImportService: Import completed successfully with #{headers.length} headers"
      { success: true, message: 'Import completed successfully' }
    rescue => e
      Rails.logger.error "📥 ImportService ERROR: #{e.message}"
      Rails.logger.error "📥 ImportService ERROR: #{e.backtrace.join('\n')}"

      # Save error message to the import record
      @import.update!(
        status: 'failed',
        error_message: "#{e.class.name}: #{e.message}"
      )

      { success: false, message: "Import failed: #{e.message}" }
    end
  end
  
  private
  
  def download_csv
    uri = URI(CSV_URL)

    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Get.new(uri)
      response = http.request(request)

      raise "Failed to download file: #{response.code}" unless response.code == '200'

      response.body
    end
  end

  def create_zip_file(csv_content)
    # Create ZIP file in memory using StringIO
    zip_buffer = StringIO.new
    
    Zip::OutputStream.write_buffer(zip_buffer) do |zipfile|
      zipfile.put_next_entry('insales.csv')
      zipfile.write(csv_content)
    end
    
    zip_buffer.string
  end
  
  def extract_headers(csv_content)
    require 'csv'

    begin
      # Ensure proper encoding for CSV content
      safe_csv_content = csv_content.force_encoding('UTF-8')
      safe_csv_content = safe_csv_content.scrub('?') unless safe_csv_content.valid_encoding?

      # Parse CSV to get headers (first row)
      csv = CSV.parse(safe_csv_content, headers: true)
      headers = csv.headers

      if headers.present?
        Rails.logger.info "📥 ImportService: Extracted #{headers.length} headers: #{headers.join(', ')}"
        headers
      else
        Rails.logger.warn "📥 ImportService: No headers found in CSV"
        []
      end
    rescue => e
      Rails.logger.error "📥 ImportService: Error extracting headers: #{e.message}"
      []
    end
  end
end
