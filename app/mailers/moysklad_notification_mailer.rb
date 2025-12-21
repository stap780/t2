class MoyskladNotificationMailer < ApplicationMailer
  default from: "robot@gmail.com"
  
  def create_products_batch_result(email_delivery_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @moysklad = @email_delivery.recipient
    @details = @email_delivery.operation_details
    @success = @email_delivery.sent?
    
    subject = @success ? 
      "✅ Массовое создание товаров в МойСклад - успешно" :
      "❌ Массовое создание товаров в МойСклад - ошибка"
    
    mail(
      to: @email_delivery.recipient_email,
      subject: subject,
      reply_to: "robot@gmail.com"
    )
  end
  
  def update_quantities_result(email_delivery_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @moysklad = @email_delivery.recipient
    @details = @email_delivery.operation_details
    @success = @email_delivery.sent?
    
    subject = @success ? 
      "✅ Обновление остатков из МойСклад - успешно" :
      "❌ Обновление остатков из МойСклад - ошибка"
    
    mail(
      to: @email_delivery.recipient_email,
      subject: subject,
      reply_to: "robot@gmail.com"
    )
  end
end

