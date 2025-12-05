# Job для генерации Excel файла перед отправкой
class GenerateIncaseExcelJob < ApplicationJob
  queue_as :default
  
  def perform(incase_id, company_id)
    require 'caxlsx'
    require 'stringio'
    
    incase = Incase.find(incase_id)
    company = Company.find(company_id)
    
    # Определяем получателей
    emails = company.clients.pluck(:email).reject(&:blank?).join(',')
    recipient_email = emails.present? ? emails : "avemik@gmail.com"
    subject = emails.present? ? "#{company.short_title}. Заявка на вывоз запчастей" : "НЕТ адреса у контрагента #{company.short_title}. Заявка на вывоз запчастей"
    
    # Создаем EmailDelivery запись
    email_delivery = EmailDelivery.create!(
      recipient: company,
      record: incase,
      mailer_class: 'IncaseMailer',
      mailer_method: 'send_excel',
      recipient_email: recipient_email,
      subject: subject,
      status: 'pending'
    )
    
    begin
      # Находим статусы "Долг" и "В работе"
      item_statuses = ItemStatus.where(title: ['Долг', 'В работе'])
      item_status_ids = item_statuses.pluck(:id)
      
      # Фильтруем items по статусам
      items = incase.items.where(item_status_id: item_status_ids)
      
      # Генерируем Excel файл в памяти через caxlsx
      p = Axlsx::Package.new
      wb = p.workbook
      
      wb.add_worksheet(name: 'Позиции') do |sheet|
        # Заголовки
        sheet.add_row ['Контрагент', 'Страховая компания', 'Номер З/Н СТОА', 'Номер дела', 'Марка и Модель ТС', 'Гос номер', 'Деталь']
        
        # Данные
        items.each do |item|
          sheet.add_row [
            incase.company.title,
            incase.strah&.title || '',
            incase.stoanumber || '',
            incase.unumber || '',
            incase.modelauto || '',
            incase.carnumber || '',
            item.title || ''
          ]
        end
      end
      
      # Генерируем Excel в память
      excel_data = StringIO.new
      p.serialize(excel_data)
      excel_data.rewind
      
      # Прикрепляем Excel к EmailDelivery
      email_delivery.attachment.attach(
        io: excel_data,
        filename: "#{incase.id}.xlsx",
        content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      )
      
      # Запускаем Job для отправки письма
      IncaseEmailJob.perform_later(incase_id, company_id, email_delivery.id)
      
    rescue => e
      email_delivery.update!(
        status: 'failed',
        error_message: "Excel generation failed: #{e.class}: #{e.message}"
      )
      raise
    end
  end
end

