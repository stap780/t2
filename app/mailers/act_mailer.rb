class ActMailer < ApplicationMailer
  layout 'act_mailer'
  default from: "robot@gmail.com"
  
  def send_pdf(user_id, email_delivery_id)
    @user = User.find(user_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @app_name = 'CarParts - управление запчастями'
    
    # Читаем PDF из Active Storage attachment
    if @email_delivery.attachment.attached?
      attachments['acts.pdf'] = @email_delivery.attachment.download
    end
    
    mail(
      to: @user.email_address,
      subject: @email_delivery.subject || "Робот Carparts - файл с актами от #{Time.now.in_time_zone.strftime("%d/%m/%Y")}",
      reply_to: "robot@gmail.com"
    )
  end
end

