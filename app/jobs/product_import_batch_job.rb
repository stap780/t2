class ProductImportBatchJob < ApplicationJob
  queue_as :product_import
  
  # Retry при временных ошибках
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3
  
  # Не повторять при ошибках валидации
  discard_on ActiveRecord::RecordInvalid
  
  def perform(batch_data, properties_cache: {}, characteristics_cache: {})
    Rails.logger.info "📦 ProductImportBatchJob: Processing batch of #{batch_data.count} products"
    
    created_count = 0
    updated_count = 0
    errors = []
    
    # Обрабатываем батч в одной транзакции для консистентности
    ActiveRecord::Base.transaction do
      batch_data.each_with_index do |row, index|
        begin
          result = process_single_product(row, properties_cache, characteristics_cache)
          
          if result[:success]
            if result[:created]
              created_count += 1
            else
              updated_count += 1
            end
            
            # Запускаем загрузку изображений асинхронно
            if result[:images_urls].present?
              ProductImageJob.perform_later(result[:product].id, result[:images_urls])
            end
          else
            errors << { row: index, error: result[:error] }
          end
        rescue => e
          error_msg = "Row #{index}: #{e.class} - #{e.message}"
          Rails.logger.error "📦 ProductImportBatchJob ERROR: #{error_msg}"
          errors << { row: index, error: error_msg }
        end
      end
    end
    
    Rails.logger.info "📦 ProductImportBatchJob: Completed. Created: #{created_count}, Updated: #{updated_count}, Errors: #{errors.count}"
    
    {
      created: created_count,
      updated: updated_count,
      errors: errors
    }
  end
  
  private
  
  def process_single_product(row, properties_cache, characteristics_cache)
    # Преобразуем CSV row в hash
    data = row.is_a?(Hash) ? row : row.to_h
    
    # Используем Product::ImportSaveData для обработки
    result = Product::ImportSaveData.new(
      data,
      properties_cache: properties_cache,
      characteristics_cache: characteristics_cache
    ).call
    
    if result[:success]
      {
        success: true,
        product: result[:product],
        created: result[:created],
        images_urls: result[:images_urls]
      }
    else
      result
    end
  end
end

