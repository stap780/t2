# Унифицированный Job для отправки писем (одиночных и массовых)
class IncaseEmailJob < ApplicationJob
  queue_as :mailers
  
  # incase_ids: массив ID убытков (даже если один элемент)
  # company_id: ID компании
  # email_delivery_id: ID EmailDelivery записи
  def perform(incase_ids, company_id, email_delivery_id)
    email_delivery = EmailDelivery.find(email_delivery_id)
    company = Company.find(company_id)
    
    # Проверяем, что файл уже прикреплен
    return unless email_delivery.attachment.attached?
    
    begin
      # Нормализуем массив ID
      incase_ids = Array(incase_ids)
      
      # Отправляем письмо через mailer
      mailer = IncaseMailer.send_excel(incase_ids, company_id, email_delivery.id)
      mailer.deliver_now
      
      email_delivery.update!(
        status: 'sent',
        sent_at: Time.current
      )
      
      # Обновляем sendstatus для всех убытков
      Incase.where(id: incase_ids).update_all(sendstatus: true)
      
    rescue => e
      email_delivery.update!(
        status: 'failed',
        error_message: "#{e.class}: #{e.message}"
      )
      raise
    end
  end
end
