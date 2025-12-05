class EmailDelivery < ApplicationRecord
  belongs_to :recipient, polymorphic: true
  belongs_to :record, polymorphic: true
  
  # Универсальный Active Storage attachment для хранения файлов (PDF или Excel)
  has_one_attached :attachment
  
  enum :status, { pending: 'pending', sent: 'sent', failed: 'failed' }
  
  scope :for_record, ->(record) { where(record: record) }
  scope :recent, -> { order(created_at: :desc) }
  
  def self.ransackable_attributes(auth_object = nil)
    %w[id status recipient_email mailer_class mailer_method subject created_at sent_at]
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[recipient record]
  end
  
  # Проверка типа файла
  def pdf_file?
    attachment.attached? && attachment.content_type == 'application/pdf'
  end
  
  def excel_file?
    attachment.attached? && ['application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'].include?(attachment.content_type)
  end
end

