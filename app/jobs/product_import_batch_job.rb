class ProductImportBatchJob < ApplicationJob
  queue_as :product_import
  
  # Retry при временных ошибках
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3
  
  # Не повторять при ошибках валидации
  discard_on ActiveRecord::RecordInvalid
  
  def perform(product_data, properties_cache: {}, characteristics_cache: {})
    # Обрабатываем один товар: данные собираются сразу, товар создаётся/обновляется
    Rails.logger.info "📦 ProductImportBatchJob: Processing product"
    
    begin
      result = process_single_product(product_data, properties_cache, characteristics_cache)
      
      if result[:success]
        # Запускаем загрузку изображений асинхронно
        if result[:images_urls].present?
          ProductImageJob.perform_later(result[:product].id, result[:images_urls])
        end
        
        status = result[:created] ? 'created' : 'updated'
        Rails.logger.info "📦 ProductImportBatchJob: Product #{status} - #{result[:product].title}"
        
        {
          success: true,
          created: result[:created],
          product: result[:product]
        }
      else
        Rails.logger.error "📦 ProductImportBatchJob ERROR: #{result[:error]}"
        {
          success: false,
          error: result[:error]
        }
      end
    rescue => e
      error_msg = "#{e.class} - #{e.message}"
      Rails.logger.error "📦 ProductImportBatchJob ERROR: #{error_msg}"
      {
        success: false,
        error: error_msg
      }
    end
  end
  
  private
  
  def process_single_product(product_data, properties_cache, characteristics_cache)
    # Данные уже в формате Hash
    data = product_data.is_a?(Hash) ? product_data : product_data.to_h
    
    # Используем Product::ImportSaveData для обработки
    # Данные собираются сразу, товар создаётся/обновляется
    Product::ImportSaveData.new(
      data,
      properties_cache: properties_cache,
      characteristics_cache: characteristics_cache
    ).call
  end
end

