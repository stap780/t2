# Job для генерации Excel файла перед отправкой
class GenerateIncaseExcelJob < ApplicationJob
  queue_as :generate_incase_excel
  
  # Унифицированный метод: принимает массив incase_ids (даже если один элемент)
  # incase_ids: массив ID убытков
  # company_id: ID компании
  # email_delivery_id: ID существующей EmailDelivery записи (создается в IncaseEmailService)
  def perform(incase_ids, company_id, email_delivery_id)
    require 'caxlsx'
    require 'tempfile'
    
    # Нормализуем входные данные: всегда массив
    incase_ids = Array(incase_ids)
    return if incase_ids.empty?
    
    # Загружаем убытки с items и их статусами
    incases = Incase.where(id: incase_ids).includes(:company, :strah, items: :item_status)
    return if incases.empty?
    
    # Находим EmailDelivery запись (создается в IncaseEmailService)
    email_delivery = EmailDelivery.find(email_delivery_id)
    company = Company.find(company_id)
    
    begin
      # Генерируем Excel файл
      p = Axlsx::Package.new
      wb = p.workbook
      
      wb.add_worksheet(name: 'Позиции') do |sheet|
        # Заголовки
        sheet.add_row ['Контрагент', 'Страховая компания', 'Номер З/Н СТОА', 'Номер дела', 'Марка и Модель ТС', 'Гос номер', 'Деталь', 'Статус детали']
        
        # Данные из всех убытков - включаем все items, не только "Долг" и "В работе"
        incases.each do |incase|
          incase.items.each do |item|
            sheet.add_row [
              incase.company.title,
              incase.strah&.title || '',
              incase.stoanumber || '',
              incase.unumber || '',
              incase.modelauto || '',
              incase.carnumber || '',
              item.title || '',
              item.item_status&.title || ''
            ]
          end
        end
      end
      
      # Генерируем Excel во временный файл
      temp_file = Tempfile.new(['incase', '.xlsx'])
      p.serialize(temp_file.path)
      temp_file.rewind
      
      # Определяем имя файла
      filename = if incase_ids.size == 1
        "#{incase_ids.first}.xlsx"
      else
        "#{company.short_title.gsub(' ', '_').gsub('/', '_')}_#{Time.zone.now.strftime('%d_%m_%Y')}.xlsx"
      end
      
      # Прикрепляем Excel к EmailDelivery
      email_delivery.attachment.attach(
        io: temp_file,
        filename: filename,
        content_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      )
      
      temp_file.close
      temp_file.unlink
      
      # Запускаем Job для отправки письма
      IncaseEmailJob.perform_later(incase_ids, company.id, email_delivery.id)
      
    rescue => e
      email_delivery.update!(
        status: 'failed',
        error_message: "Excel generation failed: #{e.class}: #{e.message}"
      )
      raise
    end
  end
end
