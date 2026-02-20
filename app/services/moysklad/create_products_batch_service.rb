class Moysklad::CreateProductsBatchService
  # Email для уведомлений (можно вынести в настройки)
  NOTIFICATION_EMAIL = Rails.application.credentials.dig(:moysklad_notification_email) || 'dizautodealer@gmail.com'
  
  def initialize(moysklad_config = nil)
    @moysklad = moysklad_config || Moysklad.first
    raise ArgumentError, "Moysklad configuration not found" unless @moysklad
  end

  def call
    # Товары без varbind Moysklad и со статусом pending
    products_without_binding = Product.where(status: 'pending').where.not(
        id: Varbind.where(bindable_type: 'Moysklad', bindable_id: @moysklad.id)
                   .where(record_type: 'Product').select(:record_id)
      )

    total = products_without_binding.count
    
    if total.zero?
      Rails.logger.info "Moysklad::CreateProductsBatchService: No products to create"
      return { success: true, created_count: 0, error_count: 0, error_412_count: 0, total: 0, created_product_ids: [], error_412_product_ids: [], error_product_ids: [] }
    end

    created_count = 0
    error_count = 0
    error_412_count = 0
    created_product_ids = []
    error_412_product_ids = []
    error_product_ids = []

    products_without_binding.find_each(batch_size: 100) do |product|
      begin
        service = Moysklad::SyncProductService.new(product, @moysklad)
        result = service.call

        if result[:success]
          created_count += 1
          created_product_ids << product.id
          Rails.logger.info "Moysklad::CreateProductsBatchService: Product ##{product.id} created in Moysklad" if (created_count % 100).zero?
        elsif result[:error_code] == 412
          error_412_count += 1
          error_412_product_ids << product.id
          Rails.logger.warn "Moysklad::CreateProductsBatchService: Product ##{product.id} - error 412 (duplicate code)" if (error_412_count % 10).zero?
        else
          error_count += 1
          error_product_ids << { product_id: product.id, error: result[:error].to_s }
          Rails.logger.error "Moysklad::CreateProductsBatchService: Product ##{product.id} - error: #{result[:error]}" if (error_count % 10).zero?
        end
      rescue StandardError => e
        error_count += 1
        error_product_ids << { product_id: product.id, error: "#{e.class}: #{e.message}" }
        Rails.logger.error "Moysklad::CreateProductsBatchService: Error for product #{product.id}: #{e.class} - #{e.message}"
      end
    end

    result = {
      success: true,
      created_count: created_count,
      error_count: error_count,
      error_412_count: error_412_count,
      total: total,
      created_product_ids: created_product_ids,
      error_412_product_ids: error_412_product_ids,
      error_product_ids: error_product_ids
    }
    
    Rails.logger.info "Moysklad::CreateProductsBatchService: Completed. Created: #{created_count}, Errors: #{error_count}, Errors 412: #{error_412_count}, Total: #{total}"
    
    # Создаем EmailDelivery запись и отправляем уведомление о массовом создании
    create_email_delivery_and_notify(result)
    
    result
  rescue StandardError => e
    Rails.logger.error "Moysklad::CreateProductsBatchService: Fatal error - #{e.class}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: "#{e.class}: #{e.message}" }
  end
  
  private
  
  def create_email_delivery_and_notify(result)
    return unless result[:success]
    
    success = result[:error_count].zero? && result[:error_412_count].zero?
    
    subject = success ? 
      "✅ Массовое создание товаров в МойСклад - успешно" :
      "⚠️ Массовое создание товаров в МойСклад - завершено с ошибками"
    
    metadata = {
      moysklad_id: @moysklad.id,
      result: success ? 'success' : 'completed_with_errors',
      details: {
        created_count: result[:created_count],
        error_count: result[:error_count],
        error_412_count: result[:error_412_count],
        total: result[:total],
        completed_at: Time.current.iso8601,
        created_product_ids: result[:created_product_ids],
        error_412_product_ids: result[:error_412_product_ids],
        error_product_ids: result[:error_product_ids]&.map { |e| { product_id: e[:product_id], error: e[:error].to_s } }
      }
    }
    
    email_delivery = EmailDelivery.create!(
      recipient: @moysklad,
      record: nil,
      mailer_class: 'MoyskladNotificationMailer',
      mailer_method: 'create_products_batch_result',
      recipient_email: NOTIFICATION_EMAIL,
      subject: subject,
      status: 'pending',
      metadata: metadata
    )
    
    # Отправляем email уведомление асинхронно
    MoyskladNotificationJob.perform_later(email_delivery.id)
  rescue StandardError => e
    Rails.logger.error "Moysklad::CreateProductsBatchService: Error creating email delivery: #{e.class} - #{e.message}"
    # Не прерываем выполнение, если не удалось создать EmailDelivery
  end
end

