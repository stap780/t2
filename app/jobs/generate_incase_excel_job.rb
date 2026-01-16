# Job для генерации Excel файла перед отправкой
class GenerateIncaseExcelJob < ApplicationJob
  queue_as :default
  
  def perform(mode, *args)
    if mode == 'multiple'
      perform_multiple(*args)
    elsif mode == 'single'
      perform_single(*args)
    else
      # Обратная совместимость: если первый аргумент не 'multiple' или 'single', значит это старый формат (incase_id, company_id)
      perform_single(mode, *args)
    end
  end
  
  private
  
  def perform_single(incase_id, company_id)
    require 'caxlsx'
    require 'tempfile'
    
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
      
      # Генерируем Excel во временный файл
      temp_file = Tempfile.new(['incase', '.xlsx'])
      p.serialize(temp_file.path)
      temp_file.rewind
      
      # Прикрепляем Excel к EmailDelivery
      email_delivery.attachment.attach(
        io: temp_file,
        filename: "#{incase.id}.xlsx",
        content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      )
      
      temp_file.close
      temp_file.unlink
      
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
  
  def perform_multiple(company_id, incase_ids, email_delivery_id)
    require 'caxlsx'
    require 'tempfile'
    
    company = Company.find(company_id)
    incases = Incase.where(id: incase_ids).includes(:company, :strah, items: :item_status)
    email_delivery = EmailDelivery.find(email_delivery_id)
    
    # Находим статусы "Долг" и "В работе"
    item_statuses = ItemStatus.where(title: ['Долг', 'В работе'])
    item_status_ids = item_statuses.pluck(:id)
    
    # Генерируем Excel файл в памяти через caxlsx
    p = Axlsx::Package.new
    wb = p.workbook
    
    wb.add_worksheet(name: 'Позиции') do |sheet|
      # Заголовки
      sheet.add_row ['Контрагент', 'Страховая компания', 'Номер З/Н СТОА', 'Номер дела', 'Марка и Модель ТС', 'Гос номер', 'Деталь']
      
      # Данные из всех убытков компании
      incases.each do |incase|
        # Фильтруем items по статусам для каждого убытка
        items = incase.items.where(item_status_id: item_status_ids)
        
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
    end
    
    # Генерируем Excel во временный файл
    temp_file = Tempfile.new(['incase_multiple', '.xlsx'])
    p.serialize(temp_file.path)
    temp_file.rewind
    
    # Прикрепляем Excel к EmailDelivery
    filename = "#{company.short_title.gsub(' ', '_').gsub('/', '_')}_#{Time.zone.now.strftime('%d_%m_%Y')}.xlsx"
    email_delivery.attachment.attach(
      io: temp_file,
      filename: filename,
      content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
    )
    
    temp_file.close
    temp_file.unlink
    
    # Запускаем Job для отправки письма
    IncaseMultipleEmailJob.perform_later(company_id, email_delivery_id, incase_ids)
    
  rescue => e
    email_delivery.update!(
      status: 'failed',
      error_message: "Excel generation failed: #{e.class}: #{e.message}"
    )
    raise
  end
end

