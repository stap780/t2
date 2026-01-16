class IncaseMailer < ApplicationMailer
  layout 'incase_mailer'
  default from: "Авто Дизайн <dizautodealer@gmail.com>"
  
  def send_excel(incase_id, company_id, email_delivery_id)
    @incase = Incase.find(incase_id)
    @company = Company.find(company_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    
    emails = "toweleie23@gmail.com,panaet80@gmail.com" # @company.clients.pluck(:email).reject(&:blank?).join(',')
    
    if emails.blank?
      emails = "toweleie23@gmail.com"
      subject = "НЕТ адреса у контрагента #{@company.short_title}. Заявка на вывоз запчастей"
    else
      subject = "#{@company.short_title}. Заявка на вывоз запчастей"
    end
    
    # Читаем Excel из Active Storage attachment
    if @email_delivery.attachment.attached?
      filename = "#{@incase.id}.xlsx"
      attachments[filename] = @email_delivery.attachment.download
    end
    
    mail(
      to: emails,
      subject: subject,
      reply_to: "dizautodealer@gmail.com"
    )
  end
  
  def send_multiple_excel(company_id, email_delivery_id)
    @company = Company.find(company_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @incase_ids = @email_delivery.metadata&.dig('incase_ids') || []
    @incases = Incase.where(id: @incase_ids).includes(:company, :strah)
    
    emails = "toweleie23@gmail.com,panaet80@gmail.com" #@company.clients.pluck(:email).reject(&:blank?).join(',')
    
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

