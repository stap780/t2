class XlsxNotificationMailer < ApplicationMailer
  default from: "robot@gmail.com"

  def xlsx_zip_result(email_delivery_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @details = @email_delivery.operation_details
    @model_name = @details['model'] || 'данные'
    @items_count = @details['items_count'] || 0

    if @email_delivery.attachment.attached?
      filename = @email_delivery.attachment.filename.to_s
      attachments[filename] = @email_delivery.attachment.download
    end

    mail(
      to: @email_delivery.recipient_email,
      subject: @email_delivery.subject,
      reply_to: "robot@gmail.com"
    )
  end
end
