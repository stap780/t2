class MoyskladNotificationMailer < ApplicationMailer
  default from: "robot@gmail.com"
  
  def create_products_batch_result(email_delivery_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @moysklad = @email_delivery.recipient
    @details = @email_delivery.operation_details
    @success = @email_delivery.sent?
    mail(
      to: @email_delivery.recipient_email,
      subject: @email_delivery.subject,
      reply_to: "robot@gmail.com"
    )
  end
  
  def update_quantities_result(email_delivery_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @moysklad = @email_delivery.recipient
    @details = @email_delivery.operation_details
    @success = @email_delivery.sent?
    mail(
      to: @email_delivery.recipient_email,
      subject: @email_delivery.subject,
      reply_to: "robot@gmail.com"
    )
  end
end

