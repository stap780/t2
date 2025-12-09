class ActEmailJob < ApplicationJob
  queue_as :mailers
  
  def perform(user_id, email_delivery_ids)
    user = User.find(user_id)
    email_deliveries = EmailDelivery.where(id: email_delivery_ids, status: 'pending')
    
    return if email_deliveries.empty?
    
    # Находим первый EmailDelivery с прикрепленным файлом (все должны иметь один и тот же файл)
    main_email_delivery = email_deliveries.find { |ed| ed.attachment.attached? }
    return unless main_email_delivery
    
    acts = Act.where(id: email_deliveries.map { |ed| ed.record_id })
    
    begin
      # Отправляем письмо с PDF из Active Storage
      mailer = ActMailer.send_pdf(user_id, main_email_delivery.id)
      mailer.deliver_now
      
      # Обновляем статусы всех EmailDelivery записей
      email_deliveries.each do |ed|
        ed.update!(
          status: 'sent',
          sent_at: Time.current
        )
      end
      
      # Обновляем статусы актов
      acts.update_all(status: :sent)
    rescue => e
      email_deliveries.each do |ed|
        ed.update!(
          status: 'failed',
          error_message: "#{e.class}: #{e.message}"
        )
      end
      raise
    end
  end
end

