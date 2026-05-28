# frozen_string_literal: true

class AvitoNotificationJob < ApplicationJob
  queue_as :mailers

  def perform(email_delivery_id)
    email_delivery = EmailDelivery.find(email_delivery_id)

    return unless email_delivery.mailer_class == "AvitoNotificationMailer"

    begin
      case email_delivery.mailer_method
      when "catalog_sync_result"
        mailer = AvitoNotificationMailer.catalog_sync_result(email_delivery_id)
      else
        Rails.logger.error "AvitoNotificationJob: Unknown mailer method: #{email_delivery.mailer_method}"
        return
      end

      mailer.deliver_now

      email_delivery.update!(
        status: "sent",
        sent_at: Time.current
      )
    rescue StandardError => e
      email_delivery.update!(
        status: "failed",
        error_message: "#{e.class}: #{e.message}"
      )
      raise
    end
  end
end
