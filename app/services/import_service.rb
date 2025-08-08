require 'net/http'
require 'uri'
require 'zip'
require 'stringio'

class ImportService
  CSV_URL = 'http://138.197.52.153/insales.csv'
  
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

      # Update import record and broadcast the change
      @import.update!(
        status: 'completed',
        imported_at: Time.current
      )

      Rails.logger.info "📥 ImportService: Import completed successfully"
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
end
