# frozen_string_literal: true

class InsaleNotificationJob < ApplicationJob
  queue_as :mailers

  def perform(email_delivery_id)
    email_delivery = EmailDelivery.find(email_delivery_id)

    return unless email_delivery.mailer_class == "InsaleNotificationMailer"

    begin
      case email_delivery.mailer_method
      when "varbind_sync_result"
        mailer = InsaleNotificationMailer.varbind_sync_result(email_delivery_id)
      when "prices_update_result"
        mailer = InsaleNotificationMailer.prices_update_result(email_delivery_id)
      when "images_sync_result"
        mailer = InsaleNotificationMailer.images_sync_result(email_delivery_id)
      else
        Rails.logger.error "InsaleNotificationJob: Unknown mailer method: #{email_delivery.mailer_method}"
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
