# frozen_string_literal: true

class IncaseCalcPriceJob < ApplicationJob
  queue_as :default

  # При вызове без аргументов — полный пересчёт + создание EmailDelivery + отправка.
  # При вызове с email_delivery_id — только повторная отправка (для retry).
  def perform(email_delivery_id = nil)
    if email_delivery_id.present?
      send_notification(email_delivery_id)
      return
    end

    run_calc_and_notify
  end

  private

  def run_calc_and_notify
    yesterday = 1.day.ago.all_day

    variant_ids = Audited::Audit
      .where(auditable_type: "Variant")
      .where("audited_changes ? 'price'")
      .where(created_at: yesterday)
      .pluck(:auditable_id)
      .uniq

    incase_ids = []
    errors = []

    if variant_ids.any?
      incase_ids = Item.where(variant_id: variant_ids).distinct.pluck(:incase_id)

      Incase.where(id: incase_ids).find_each do |incase|
        success, message = incase.item_prices
        if success
          Rails.logger.info "IncaseCalcPriceJob: incase ##{incase.id} - OK"
        else
          errors << "Убыток ##{incase.id}: #{message}"
          Rails.logger.warn "IncaseCalcPriceJob: incase ##{incase.id} - #{message}"
        end
      end
    end

    create_and_send_email_delivery(
      processed_count: incase_ids.size,
      incase_ids: incase_ids,
      errors: errors
    )
  end

  def create_and_send_email_delivery(processed_count:, incase_ids:, errors:)
    recipient = User.first || Company.first
    recipient_email = "panaet80@gmail.com, avemik@gmail.com"
    subject = errors.empty? ? "✅ Массовый пересчет себестоимости - успешно" : "⚠️ Массовый пересчет себестоимости - завершено с ошибками"

    email_delivery = EmailDelivery.create!(
      recipient: recipient,
      record: nil,
      mailer_class: "IncaseMailer",
      mailer_method: "incase_item_prices_result",
      recipient_email: recipient_email,
      subject: subject,
      status: "pending",
      metadata: {
        result: errors.empty? ? "success" : "completed_with_errors",
        details: {
          processed_count: processed_count,
          incase_ids: incase_ids,
          errors: errors,
          completed_at: Time.current.iso8601
        }
      }
    )

    send_notification(email_delivery.id)
  end

  def send_notification(email_delivery_id)
    email_delivery = EmailDelivery.find(email_delivery_id)
    return unless email_delivery.mailer_class == "IncaseMailer" && email_delivery.mailer_method == "incase_item_prices_result"

    IncaseMailer.incase_item_prices_result(email_delivery_id).deliver_now
    email_delivery.update!(status: "sent", sent_at: Time.current)
  rescue => e
    email_delivery.update!(status: "failed", error_message: "#{e.class}: #{e.message}")
    raise
  end
end
