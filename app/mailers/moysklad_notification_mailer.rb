class MoyskladNotificationMailer < ApplicationMailer
  default from: "robot@gmail.com"
  
  def create_products_batch_result(email_delivery_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @moysklad = @email_delivery.recipient
    @details = @email_delivery.operation_details
    @success = @email_delivery.operation_result == 'success'

    created_ids = @details['created_product_ids'].to_a
    error_412_ids = @details['error_412_product_ids'].to_a
    error_items = @details['error_product_ids'].to_a

    @created_products = Product.where(id: created_ids).index_by(&:id).values_at(*created_ids).compact
    @error_412_products = Product.where(id: error_412_ids).index_by(&:id).values_at(*error_412_ids).compact
    @error_products = error_items.map do |item|
      product = Product.find_by(id: item['product_id'])
      { product: product, product_id: item['product_id'], error: item['error'] }
    end

    mail(
      to: @email_delivery.recipient_email,
      subject: @email_delivery.subject,
      reply_to: "robot@gmail.com"
    )
  end
  
  def update_quantities_result(email_delivery_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @moysklad = @email_delivery.recipient
    @details = @email_delivery.operation_details
    @success = @email_delivery.operation_result == 'success'
    mail(
      to: @email_delivery.recipient_email,
      subject: @email_delivery.subject,
      reply_to: "robot@gmail.com"
    )
  end

  def update_prices_result(email_delivery_id)
    @email_delivery = EmailDelivery.find(email_delivery_id)
    @details = @email_delivery.operation_details
    @success = @email_delivery.operation_result == 'success'
    mail(
      to: @email_delivery.recipient_email,
      subject: @email_delivery.subject,
      reply_to: "robot@gmail.com"
    )
  end
end

