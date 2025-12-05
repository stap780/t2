class EmailDeliveriesController < ApplicationController
  def index
    @search = EmailDelivery.includes(:recipient, :record)
                           .ransack(params[:q])
    @search.sorts = "created_at desc" if @search.sorts.empty?
    @email_deliveries = @search.result(distinct: true)
                                .paginate(page: params[:page], per_page: 50)
  end
  
  def show
    @email_delivery = EmailDelivery.find(params[:id])
  end
  
  def retry
    @email_delivery = EmailDelivery.find(params[:id])
    
    # Проверяем, что файл прикреплен
    unless @email_delivery.attachment.attached?
      redirect_to @email_delivery, alert: 'Файл не найден. Необходимо сгенерировать файл заново.'
      return
    end
    
    case @email_delivery.mailer_class
    when 'IncaseMailer'
      IncaseEmailJob.perform_later(
        @email_delivery.record.id,
        @email_delivery.recipient.id,
        @email_delivery.id
      )
    when 'ActMailer'
      # Для актов нужно найти все EmailDelivery записи для этого пользователя и актов
      user = @email_delivery.recipient
      act_ids = EmailDelivery.where(
        recipient: user,
        mailer_class: 'ActMailer',
        status: ['pending', 'failed']
      ).pluck(:record_id).uniq
      
      ActEmailJob.perform_later(user.id, [@email_delivery.id])
    end
    
    redirect_to @email_delivery, notice: 'Повторная отправка запланирована'
  end
end

