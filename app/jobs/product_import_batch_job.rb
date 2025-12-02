class ProductImportBatchJob < ApplicationJob
  queue_as :product_import
  
  # Retry при временных ошибках
  retry_on ActiveRecord::Deadlocked, wait: 5.seconds, attempts: 3
  retry_on ActiveRecord::LockWaitTimeout, wait: 5.seconds, attempts: 3
  
  # Не повторять при ошибках валидации
  discard_on ActiveRecord::RecordInvalid
  
  # product_data может быть:
  # - Hash (один товар) — для совместимости со старыми job'ами
  # - Array<Hash> (батч товаров) — новый формат
  def perform(product_data, properties_cache: {}, characteristics_cache: {})
    products = product_data.is_a?(Array) ? product_data : [product_data]
    batch_size = products.size
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

    Rails.logger.info "📦 ProductImportBatchJob: Processing batch of #{batch_size} products"

    products.each_with_index do |data, index|
      begin
        result = process_single_product(data, properties_cache, characteristics_cache)

        if result[:success]
          # Запускаем загрузку изображений асинхронно
          if result[:images_urls].present?
            ProductImageJob.perform_later(result[:product].id, result[:images_urls])
          end

          status = result[:created] ? 'created' : 'updated'
          Rails.logger.info "📦 ProductImportBatchJob: [#{index + 1}/#{batch_size}] Product #{status} - #{result[:product].title}"
        else
          Rails.logger.error "📦 ProductImportBatchJob ERROR: [#{index + 1}/#{batch_size}] #{result[:error]}"
        end
      rescue => e
        error_msg = "#{e.class} - #{e.message}"
        Rails.logger.error "📦 ProductImportBatchJob ERROR: [#{index + 1}/#{batch_size}] #{error_msg}"
      end
    end

    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
    Rails.logger.info "📦 ProductImportBatchJob: Finished batch of #{batch_size} products in #{(duration * 1000).round}ms"
  end
  
  private
  
  def process_single_product(product_data, properties_cache, characteristics_cache)
    # Данные уже в формате Hash (от CSV::Row), приводим к HashWithIndifferentAccess,
    # чтобы можно было обращаться и по строковым, и по символьным ключам
    data = (product_data.is_a?(Hash) ? product_data : product_data.to_h).with_indifferent_access
    
    # Используем Product::ImportSaveData для обработки
    # Данные собираются сразу, товар создаётся/обновляется
    Product::ImportSaveData.new(
      data,
      properties_cache: properties_cache,
      characteristics_cache: characteristics_cache
    ).call
  end
end

