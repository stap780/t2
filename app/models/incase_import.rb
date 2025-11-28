class IncaseImport < ApplicationRecord
  include ActionView::RecordIdentifier
  
  belongs_to :user
  has_one_attached :file
  has_many :incase_dubls, dependent: :destroy
  
  enum :status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }, default: 'pending'
  
  validates :file, presence: true, unless: -> { source == 'json_import' }

  after_update_commit { broadcast_replace_to "incase_imports" }
  
  attr_accessor :source
  
  scope :recent, -> { order(created_at: :desc) }
  
  def has_errors?
    failed? && import_errors.present?
  end
  
  def status_color
    case status_before_type_cast
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
  
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end
  
  def self.ransackable_associations(auth_object = nil)
    ['user']
  end
end

