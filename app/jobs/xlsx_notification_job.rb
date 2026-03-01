class XlsxNotificationJob < ApplicationJob
  queue_as :mailers

  def perform(email_delivery_id)
    email_delivery = EmailDelivery.find(email_delivery_id)

    return unless email_delivery.mailer_class == 'XlsxNotificationMailer'

    begin
      case email_delivery.mailer_method
      when 'xlsx_zip_result'
        mailer = XlsxNotificationMailer.xlsx_zip_result(email_delivery_id)
      else
        Rails.logger.error "XlsxNotificationJob: Unknown mailer method: #{email_delivery.mailer_method}"
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
