class IncaseMultipleEmailJob < ApplicationJob
  queue_as :mailers
  
  def perform(company_id, email_delivery_id, incase_ids)
    email_delivery = EmailDelivery.find(email_delivery_id)
    company = Company.find(company_id)
    
    # Проверяем, что файл уже прикреплен
    return unless email_delivery.attachment.attached?
    
    begin
      mailer = IncaseMailer.send_multiple_excel(company_id, email_delivery.id)
      mailer.deliver_now
      
      email_delivery.update!(
        status: 'sent',
        sent_at: Time.current
      )
      
      # Обновляем sendstatus для всех отправленных убытков
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
