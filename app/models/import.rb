class Import < ApplicationRecord
  # Use Rails 8 associations
  belongs_to :user

  # Active Storage attachment for the ZIP file
  has_one_attached :zip_file

  after_update_commit { broadcast_replace_to "imports" }

  # Use Rails 8 query methods and optimizations
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: "completed") }
  scope :pending, -> { where(status: "pending") }
  scope :failed, -> { where(status: "failed") }
  scope :with_errors, -> { where(status: "failed").where.not(error_message: [nil, ""]) }

  # Leverage Rails 8 security features
  validates :name, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  validates :user, presence: true
  
  # Callbacks
  before_validation :set_default_name, on: :create
  
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
      'text-green-600 bg-green-100'
    when 'processing'
      'text-blue-600 bg-blue-100'
    when 'failed'
      'text-red-600 bg-red-100'
    else
      'text-yellow-600 bg-yellow-100'
    end
  end
  
  def name_with_info
    "#{name} (#{created_at.strftime('%m/%d/%Y')} - #{status.titleize})"
  end
  
  private
  
  def set_default_name
    if name.blank?
      self.name = "Import #{Time.current.strftime('%Y%m%d_%H%M%S')}"
    end
  end
end
