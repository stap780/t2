class Export < ApplicationRecord
  # Use Rails 8 associations
  belongs_to :user

  # Active Storage attachment for the exported file
  has_one_attached :export_file

  # Use Rails 8 callbacks for real-time updates
  after_create_commit { broadcast_prepend_to "exports" }
  after_update_commit { broadcast_replace_to "exports" }
  after_destroy_commit { broadcast_remove_to "exports" }

  # Use Rails 8 query methods and optimizations
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: "completed") }
  scope :pending, -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :failed, -> { where(status: "failed") }
  scope :with_errors, -> { where(status: "failed").where.not(error_message: [nil, ""]) }
  scope :test_exports, -> { where(test: true) }
  scope :production_exports, -> { where(test: false) }

  # Leverage Rails 8 security features
  validates :name, presence: true
  validates :format, presence: true, inclusion: { in: %w[csv xlsx xml] }
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  validates :user, presence: true
  
  # Format constants inspired by Dizauto
  FORMATS = [
    ['CSV', 'csv'],
    ['Excel (XLSX)', 'xlsx'],
    ['XML', 'xml']
  ].freeze

  STATUS = %w[pending processing completed failed].freeze

  # Test mode limit
  TEST_LIMIT = 10

  # Callbacks
  before_validation :set_default_name, on: :create
  before_validation :set_default_test_mode, on: :create
  
  def completed?
    status == "completed"
  end
  
  def pending?
    status == "pending"
  end
  
  def processing?
    status == "processing"
  end
  
  def failed?
    status == "failed"
  end
  
  def has_error?
    failed? && error_message.present?
  end
  
  def error_summary
    return nil unless has_error?
    
    # Truncate long error messages for display
    error_message.length > 100 ? "#{error_message[0..97]}..." : error_message
  end
  
  def status_color
    case status
    when 'completed'
      'bg-green-100 text-green-800'
    when 'processing'
      'bg-blue-100 text-blue-800'
    when 'failed'
      'bg-red-100 text-red-800'
    else
      'bg-yellow-100 text-yellow-800'
    end
  end

  def test_mode?
    test == true
  end

  def production_mode?
    !test_mode?
  end

  def record_limit
    test_mode? ? TEST_LIMIT : nil
  end

  # Extract data for template rendering (inspired by Dizauto)
  def data
    @data ||= begin
      # Use the last created import (from any user) as data source
      last_import = Import.completed.recent.first
      
      if last_import.present?
        extract_data_from_import(last_import)
      else
        # Return empty array if no imports found
        Rails.logger.warn "🎯 Export ##{id}: No completed imports found in the system"
        []
      end
    end
  end

  # Convert to Liquid drop for template rendering (like Dizauto)
  def to_liquid
    @drop ||= Drop::Export.new(self)
  end

  def has_data_source?
    Import.completed.any?
  end
  
  private
  
  def set_default_name
    if name.blank?
      self.name = "Export #{Time.current.strftime('%Y%m%d_%H%M%S')}"
    end
  end

  def set_default_test_mode
    # Default to test mode for new exports to prevent accidental large exports
    self.test = true if test.nil?
  end

  def extract_data_from_import(import)
    return [] unless import&.completed? && import.zip_file.attached?

    require "csv"

    begin
      Rails.logger.info "🎯 Export ##{id}: Extracting data from Import ##{import.id}"
      
      # Download and unzip the import file
      zip_data = import.zip_file.download
      csv_content = nil

      Zip::File.open_buffer(zip_data) do |zip|
        zip.each do |entry|
          if entry.name.end_with?(".csv")
            csv_content = entry.get_input_stream.read
            Rails.logger.info "🎯 Export ##{id}: Found CSV file: #{entry.name}"
            break
          end
        end
      end

      return [] unless csv_content

      # Parse CSV to array of hashes for Liquid template access
      csv_data = CSV.parse(csv_content, headers: true)
      data_array = csv_data.map(&:to_h)
      
      # Apply test mode limit if enabled
      if test_mode? && data_array.length > TEST_LIMIT
        Rails.logger.info "🎯 Export ##{id}: TEST MODE - Limiting to #{TEST_LIMIT} records (from #{data_array.length} total)"
        data_array = data_array.first(TEST_LIMIT)
      end

      Rails.logger.info "🎯 Export ##{id}: Extracted #{data_array.length} records from import"
      data_array
    rescue => e
      Rails.logger.error "🎯 Export ##{id}: Error extracting data from import: #{e.message}"
      []
    end
  end
end
