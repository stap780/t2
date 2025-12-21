class MoyskladNotificationJob < ApplicationJob
  queue_as :mailers
  
  def perform(email_delivery_id)
    email_delivery = EmailDelivery.find(email_delivery_id)
    
    return unless email_delivery.mailer_class == 'MoyskladNotificationMailer'
    
    begin
      case email_delivery.mailer_method
      when 'create_products_batch_result'
        mailer = MoyskladNotificationMailer.create_products_batch_result(email_delivery_id)
      when 'update_quantities_result'
        mailer = MoyskladNotificationMailer.update_quantities_result(email_delivery_id)
      else
        Rails.logger.error "MoyskladNotificationJob: Unknown mailer method: #{email_delivery.mailer_method}"
        return
      end
      
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

