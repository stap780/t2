class EmailDelivery < ApplicationRecord
  belongs_to :recipient, polymorphic: true
  belongs_to :record, polymorphic: true, optional: true
  
  # Универсальный Active Storage attachment для хранения файлов (PDF или Excel)
  has_one_attached :attachment
  
  enum :status, { pending: 'pending', sent: 'sent', failed: 'failed' }
  
  scope :for_record, ->(record) { where(record: record) }
  scope :recent, -> { order(created_at: :desc) }
  scope :moysklad_notifications, -> { where(mailer_class: 'MoyskladNotificationMailer') }
  
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
  
  # Методы для Moysklad уведомлений
  def moysklad_notification?
    mailer_class == 'MoyskladNotificationMailer'
  end
  
  # Методы для получения данных из metadata
  def operation_result
    metadata&.dig('result') || (sent? ? 'success' : 'failed')
  end
  
  def operation_details
    metadata&.dig('details') || {}
  end
  
  def operation_type_name
    case mailer_method
    when 'create_products_batch_result'
      'Массовое создание товаров'
    when 'update_quantities_result'
      'Обновление остатков'
    else
      mailer_method
    end
  end
end

