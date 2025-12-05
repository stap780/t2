# Job для генерации PDF файлов актов перед отправкой
class GenerateActsPdfJob < ApplicationJob
  queue_as :default
  
  def perform(act_ids, user_id)
    require 'prawn'
    require 'combine_pdf'
    require 'stringio'
    
    # Находим получателя (водителя)
    user = User.find(user_id)
    
    # Находим акты со статусом "Новый"
    acts = Act.where(id: act_ids, status: 'Новый')
    return if acts.empty?
    
    # Создаем EmailDelivery записи для каждого акта (если еще не созданы)
    email_deliveries = acts.map do |act|
      EmailDelivery.find_or_create_by!(
        recipient: user,
        record: act,
        mailer_class: 'ActMailer',
        mailer_method: 'send_pdf',
        recipient_email: user.email_address,
        subject: "Робот Carparts - файл с актами от #{Time.now.in_time_zone.strftime("%d/%m/%Y")}",
        status: 'pending'
      )
    end
    
    begin
      # Генерируем PDF для каждого акта в памяти
      pdf_data_array = []
      acts.each do |act|
        pdf_data = act.generate_pdf
        pdf_data_array << pdf_data
      end
      
      # Объединяем PDF файлы в один
      combined_pdf = CombinePDF.new
      pdf_data_array.each do |pdf_data|
        combined_pdf << CombinePDF.parse(pdf_data)
      end
      
      # Сохраняем объединенный PDF в память
      combined_pdf_data = combined_pdf.to_pdf
      
      # Прикрепляем PDF к первой EmailDelivery записи
      main_email_delivery = email_deliveries.first
      main_email_delivery.attachment.attach(
        io: StringIO.new(combined_pdf_data),
        filename: "acts_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf",
        content_type: 'application/pdf'
      )
      
      # Запускаем Job для отправки письма
      ActEmailJob.perform_later(user.id, email_deliveries.pluck(:id))
      
    rescue => e
      # Обновляем статусы на failed при ошибке генерации
      email_deliveries.each do |ed|
        ed.update!(
          status: 'failed',
          error_message: "PDF generation failed: #{e.class}: #{e.message}"
        )
      end
      raise
    end
  end
end

