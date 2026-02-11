class IncaseEmailService
  # Унифицированный метод для отправки писем (одиночных и массовых)
  # incase_ids: массив ID убытков или один ID
  def self.send(incase_ids)
    return if incase_ids.blank?
    
    # Нормализуем входные данные: всегда массив
    incase_ids = Array(incase_ids)
    return if incase_ids.empty?
    
    # Группируем убытки по компаниям
    incases = Incase.where(id: incase_ids).includes(:company, :items)
    companies = incases.group_by(&:company_id)
    
    companies.each do |company_id, company_incases|
      company = Company.find(company_id)
      
      # Фильтруем убытки: только с sendstatus: nil и без дублей
      valid_incases = company_incases.select do |incase|
        sendstatus_nil = incase.sendstatus.nil?
        no_dubl = !IncaseDubl.where(unumber: incase.unumber, stoanumber: incase.stoanumber).exists?
        sendstatus_nil && no_dubl
      end
      
      next if valid_incases.empty?
      
      # Определяем получателей
      client_emails = company.clients.pluck(:email).reject(&:blank?)
      emails = client_emails.join(',')
      recipient_email = emails.present? ? emails : "toweleie23@gmail.com"
      subject = emails.present? ? "#{company.short_title}. Заявка на вывоз запчастей" : "НЕТ адреса у контрагента #{company.short_title}. Заявка на вывоз запчастей"
      
      # Создаем EmailDelivery запись
      email_delivery = EmailDelivery.create!(
        recipient: company,
        record: valid_incases.first,
        mailer_class: 'IncaseMailer',
        mailer_method: 'send_excel',
        recipient_email: recipient_email,
        subject: subject,
        status: 'pending',
        metadata: { incase_ids: valid_incases.map(&:id), company_id: company_id }
      )
      
      # Запускаем Job для генерации Excel файла
      GenerateIncaseExcelJob.perform_later(valid_incases.map(&:id), company_id, email_delivery.id)
    end
  end
  
  # Методы для обратной совместимости
  def self.send_multiple(incase_ids)
    send(incase_ids)
  end
  
  def self.send_one(incase_id)
    send([incase_id])
  end
end
