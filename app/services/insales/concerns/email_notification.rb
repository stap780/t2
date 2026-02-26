# frozen_string_literal: true

module Insales
  module Concerns
    module EmailNotification
      extend ActiveSupport::Concern

      NOTIFICATION_EMAIL = (Rails.application.credentials.dig(:insales_notification_email) ||
                           Rails.application.credentials.dig(:moysklad_notification_email) ||
                           "dizautodealer@gmail.com").freeze

      def create_email_delivery_and_notify(insale, result, subject_success:, subject_errors:, mailer_method:)
        return unless result[:success]

        success = (result[:errors] || 0).zero?
        subject = success ? subject_success : subject_errors

        metadata = {
          "insale_id" => insale.id,
          "result" => success ? "success" : "completed_with_errors",
          "details" => result.transform_keys(&:to_s).merge("completed_at" => Time.current.iso8601)
        }

        email_delivery = EmailDelivery.create!(
          recipient: insale,
          record: nil,
          mailer_class: "InsaleNotificationMailer",
          mailer_method: mailer_method,
          recipient_email: NOTIFICATION_EMAIL,
          subject: subject,
          status: "pending",
          metadata: metadata
        )

        InsaleNotificationJob.perform_later(email_delivery.id)
      rescue StandardError => e
        Rails.logger.error "Insales::EmailNotification: #{e.class}: #{e.message}"
      end
    end
  end
end
