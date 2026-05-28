# frozen_string_literal: true

module AvitoApi
  module EmailNotification
    NOTIFICATION_EMAIL = (Rails.application.credentials.dig(:avito_notification_email) ||
                         Rails.application.credentials.dig(:insales_notification_email) ||
                         Rails.application.credentials.dig(:moysklad_notification_email) ||
                         "dizautodealer@gmail.com").freeze

    def create_catalog_sync_email_delivery(avito, stats)
      success = stats.errors.empty?
      subject = if success
                  "✅ Синхронизация каталога Avito — успешно"
                else
                  "⚠️ Синхронизация каталога Avito — завершено с ошибками"
                end

      metadata = {
        "avito_id" => avito.id,
        "result" => success ? "success" : "completed_with_errors",
        "details" => {
          "linked" => stats.linked,
          "existing" => stats.existing,
          "not_found" => stats.not_found,
          "skipped" => stats.skipped,
          "conflicts" => stats.conflicts,
          "errors" => stats.errors.size,
          "error_messages" => stats.errors.map { |error| AvitoApi::ErrorMessage.translate(error) },
          "completed_at" => Time.current.iso8601
        }
      }

      email_delivery = EmailDelivery.create!(
        recipient: avito,
        record: nil,
        mailer_class: "AvitoNotificationMailer",
        mailer_method: "catalog_sync_result",
        recipient_email: NOTIFICATION_EMAIL,
        subject: subject,
        status: "pending",
        metadata: metadata
      )

      AvitoNotificationJob.perform_later(email_delivery.id)
    rescue StandardError => e
      Rails.logger.error "AvitoApi::EmailNotification: #{e.class}: #{e.message}"
    end
  end
end
