class IncaseEmailJob < ApplicationJob
  queue_as :mailers
  
  def perform(incase_id, company_id, email_delivery_id)
    email_delivery = EmailDelivery.find(email_delivery_id)
    incase = Incase.find(incase_id)
    company = Company.find(company_id)
    
    # Проверяем, что файл уже прикреплен
    return unless email_delivery.attachment.attached?
    
    begin
      mailer = IncaseMailer.send_excel(incase_id, company_id, email_delivery.id)
      mailer.deliver_now
      
      email_delivery.update!(
        status: 'sent',
        sent_at: Time.current
      )
    rescue => e
      email_delivery.update!(
        status: 'failed',
        error_message: "#{e.class}: #{e.message}"
      )
      raise
    end
  end
end

