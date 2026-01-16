class IncaseEmailService
  def self.send_multiple(incase_ids)
    return if incase_ids.blank?
    
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
      
      # Определяем получателей (используем заглушку для тестирования)
      client_emails = company.clients.pluck(:email).reject(&:blank?)
      emails = client_emails.join(',')
      recipient_email = emails.present? ? emails : "panaet80@gmail.com"
      subject = emails.present? ? "#{company.short_title}. Заявка на вывоз запчастей" : "НЕТ адреса у контрагента #{company.short_title}. Заявка на вывоз запчастей"
      
      # Если у компании нет клиентов с email, помечаем все убытки как неотправленные (sendstatus: false)
      # Но все равно отправляем на заглушку для тестирования
      # if client_emails.empty?
      #   valid_incases.each { |incase| incase.update(sendstatus: false) }
      #   next
      # end
      
      # Создаем EmailDelivery запись
      email_delivery = EmailDelivery.create!(
        recipient: company,
        record: valid_incases.first, # Используем первый убыток как record для связи
        mailer_class: 'IncaseMailer',
        mailer_method: 'send_multiple_excel',
        recipient_email: recipient_email,
        subject: subject,
        status: 'pending',
        metadata: { incase_ids: valid_incases.map(&:id), company_id: company_id }
      )
      
      # Запускаем Job для генерации Excel файла (массовая генерация)
      GenerateIncaseExcelJob.perform_later('multiple', company_id, valid_incases.map(&:id), email_delivery.id)
    end
  end
  
  def self.send_one(incase_id)
    incase = Incase.find(incase_id)
    company = incase.company
    
    # Проверка на наличие дубля
    if IncaseDubl.where(unumber: incase.unumber, stoanumber: incase.stoanumber).exists?
      return false
    end
    
    # Проверка наличия email у компании (проверяем наличие клиентов с email)
    # Используем заглушку для тестирования, поэтому не блокируем отправку
    # emails = company.clients.pluck(:email).reject(&:blank?)
    # if emails.empty?
    #   incase.update(sendstatus: false)
    #   return false
    # end
    
    # Используем существующий GenerateIncaseExcelJob для одиночной отправки
    GenerateIncaseExcelJob.perform_later('single', incase.id, company.id)
    true
  end
end
