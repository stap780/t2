# frozen_string_literal: true

class AvitoNotificationMailer < ApplicationMailer
  default from: "robot@gmail.com"

  def catalog_sync_result(email_delivery_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @avito = @email_delivery.recipient
    @details = @email_delivery.operation_details
    @success = @email_delivery.operation_result == "success"

    mail(
      to: @email_delivery.recipient_email,
      subject: @email_delivery.subject,
      reply_to: "robot@gmail.com"
    )
  end
end
