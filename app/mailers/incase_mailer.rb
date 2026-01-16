class IncaseMailer < ApplicationMailer
  layout 'incase_mailer'
  default from: "Авто Дизайн <dizautodealer@gmail.com>"
  
  # Унифицированный метод для отправки Excel (одиночной и массовой)
  # incase_ids: массив ID убытков (даже если один элемент)
  # company_id: ID компании
  # email_delivery_id: ID EmailDelivery записи
  def send_excel(incase_ids, company_id, email_delivery_id)
    @company = Company.find(company_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    
    # Нормализуем массив ID
    incase_ids = Array(incase_ids)
    @incase_ids = incase_ids
    @incases = Incase.where(id: incase_ids).includes(:company, :strah)
    
    # Для одиночной отправки используем первый убыток для обратной совместимости
    @incase = @incases.first if incase_ids.size == 1
    
    # Определяем получателей (заглушка для тестирования)
    emails = "toweleie23@gmail.com,panaet80@gmail.com" # @company.clients.pluck(:email).reject(&:blank?).join(',')
    
    if emails.blank?
      emails = "toweleie23@gmail.com"
      subject = "НЕТ адреса у контрагента #{@company.short_title}. Заявка на вывоз запчастей"
    else
      subject = "#{@company.short_title}. Заявка на вывоз запчастей"
    end
    
    # Читаем Excel из Active Storage attachment
    if @email_delivery.attachment.attached?
      filename = @email_delivery.attachment.filename.to_s
      attachments[filename] = @email_delivery.attachment.download
    end
    
    mail(
      to: emails,
      subject: subject,
      reply_to: "dizautodealer@gmail.com"
    )
  end
end
