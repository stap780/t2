class ProductPriceUpdateJob < ApplicationJob
  queue_as :default

  NOTIFICATION_EMAIL = Rails.application.credentials.dig(:moysklad_notification_email) || 'dizautodealer@gmail.com'

  def perform(product_ids, field_type, move, shift, points, round, current_user_id = nil)
    products = Product.where(id: product_ids)
    user = current_user_id.present? ? User.find_by(id: current_user_id) : nil

    result = if user
      Audited.audit_class.as_user(user) do
        Product::PriceUpdate.new(products, {
          field_type: field_type,
          move: move,
          shift: shift,
          points: points,
          round: round
        }).call
      end
    else
      Product::PriceUpdate.new(products, {
        field_type: field_type,
        move: move,
        shift: shift,
        points: points,
        round: round
      }).call
    end

    flash_message = result[:error_count].zero? ?
      I18n.t('we_update_price', default: 'Prices updated successfully') :
      I18n.t('we_update_price_errors', default: 'Updated with errors: %{updated} success, %{errors} failed') % {
        updated: result[:updated_count],
        errors: result[:error_count]
      }

    flash = ActionDispatch::Flash::FlashHash.new
    flash[:notice] = flash_message
    Turbo::StreamsChannel.broadcast_update_to(
      'products',
      target: 'flash',
      partial: 'shared/flash',
      layout: false,
      locals: {flash: flash}
    )

    if result[:success]
      Rails.logger.info "ProductPriceUpdateJob: Successfully updated #{result[:updated_count]} variants"
    else
      Rails.logger.warn "ProductPriceUpdateJob: Updated #{result[:updated_count]} variants, #{result[:error_count]} errors"
    end

    create_email_delivery_and_notify(result, user)
  end

  private

  def create_email_delivery_and_notify(result, user)
    success = result[:error_count].zero?
    subject = success ?
      "✅ Обновление цен - успешно" :
      "⚠️ Обновление цен - завершено с ошибками"

    metadata = {
      result: success ? 'success' : 'completed_with_errors',
      details: {
        updated_count: result[:updated_count],
        error_count: result[:error_count],
        total: result[:total],
        completed_at: Time.current.iso8601,
        errors: result[:errors].first(20)
      }
    }

    recipient, recipient_email = if user.present?
      [user, user.email_address]
    elsif (moysklad = Moysklad.first)
      [moysklad, NOTIFICATION_EMAIL]
    else
      admin = User.find_by(role: :admin)
      admin ? [admin, admin.email_address] : nil
    end

    return if recipient.blank?

    email_delivery = EmailDelivery.create!(
      recipient: recipient,
      record: nil,
      mailer_class: 'MoyskladNotificationMailer',
      mailer_method: 'update_prices_result',
      recipient_email: recipient_email,
      subject: subject,
      status: 'pending',
      metadata: metadata
    )

    MoyskladNotificationJob.perform_later(email_delivery.id)
  rescue StandardError => e
    Rails.logger.error "ProductPriceUpdateJob: Error creating email delivery: #{e.class} - #{e.message}"
  end
end

