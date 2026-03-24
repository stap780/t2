class CreateZipXlsxJob < ApplicationJob
  queue_as :create_zip_xlsx

  LONG_PROCESS_THRESHOLD = 3000
  LONG_PROCESS_MESSAGE = 'Для создания файла потребуется времени больше стандартного. Вы получите сообщение на почту с файлом после завершения процесса формирования файла. Так же вы можете проверить результат в разделе Отправка писем'

  def perform(collection_ids, options = {})
    model_name = options[:model] # 'products' or 'detals'
    model_class = model_name.singularize.camelize.constantize # 'Product' or 'Detal'
    relation = model_class.where(id: collection_ids)
    relation = relation.includes(items: :variant) if model_name == 'incases'
    download_kind = options[:download_kind]

    if collection_ids.size > LONG_PROCESS_THRESHOLD
      perform_long_process(collection_ids, model_name, relation, download_kind, options)
    else
      perform_standard(collection_ids, model_name, relation, download_kind, options)
    end
  end

  private

  def perform_long_process(collection_ids, model_name, relation, download_kind, options)
    user = User.find_by(id: options[:current_user_id])
    unless user
      broadcast_result(model_name, 'Error', 'Для отправки на почту необходимо войти в систему')
      Rails.logger.error "CreateZipXlsxJob: No user for long process (current_user_id: #{options[:current_user_id]})"
      return
    end

    broadcast_result(model_name, 'LongProcess', LONG_PROCESS_MESSAGE)

    email_delivery = EmailDelivery.create!(
      recipient: user,
      record: nil,
      mailer_class: 'XlsxNotificationMailer',
      mailer_method: 'xlsx_zip_result',
      recipient_email: user.email_address,
      subject: "Экспорт #{model_name} — #{collection_ids.size} позиций",
      status: 'pending',
      metadata: {
        details: {
          model: model_name,
          items_count: collection_ids.size,
          download_kind: download_kind
        }
      }
    )

    success, content = ZipXlsxService.new(relation, { model: model_name, download_kind: download_kind }).call

    if success
      email_delivery.attachment.attach(content)
      XlsxNotificationJob.perform_later(email_delivery.id)
      Rails.logger.info "CreateZipXlsxJob: Long process success for #{model_name}: #{collection_ids.size} items, email sent"
    else
      email_delivery.update!(status: 'failed', error_message: content.to_s)
      broadcast_result(model_name, 'Error', content)
      Rails.logger.error "CreateZipXlsxJob: Long process failed for #{model_name}: #{content.inspect}"
    end
  end

  def perform_standard(collection_ids, model_name, relation, download_kind, options)
    success, content = ZipXlsxService.new(relation, { model: model_name, download_kind: download_kind }).call
    message = success ? 'Success' : 'Error'
    broadcast_result(model_name, message, content)

    if success
      Rails.logger.info "CreateZipXlsxJob: Success for #{model_name}: #{collection_ids.count} items"
    else
      Rails.logger.error "CreateZipXlsxJob: Failed for #{model_name}: #{content.inspect}"
    end
  end

  def broadcast_result(model_name, message, content)
    Turbo::StreamsChannel.broadcast_update_to(
      model_name,
      target: 'bulk_dialog',
      partial: 'shared/pending_bulk',
      layout: false,
      locals: { message: message, content: content }
    )
  end
  
end
