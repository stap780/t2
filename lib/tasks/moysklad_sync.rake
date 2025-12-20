namespace :moysklad do
  desc "Синхронизировать товары со статусом pending без varbind Moysklad"
  task sync_pending_products: :environment do
    moysklad = Moysklad.first
    unless moysklad
      puts "❌ Конфигурация МойСклад не найдена"
      next
    end

    # Товары без varbind Moysklad и со статусом pending
    products_without_binding = Product
      .where(status: 'pending')
      .where.not(
        id: Varbind.where(bindable_type: 'Moysklad', bindable_id: moysklad.id)
                   .where(record_type: 'Product')
                   .select(:record_id)
      )

    total = products_without_binding.count
    puts "📦 Найдено товаров для синхронизации: #{total}"

    if total.zero?
      puts "✅ Нет товаров для синхронизации"
      next
    end

    synced_count = 0
    error_count = 0
    error_412_count = 0

    products_without_binding.find_each(batch_size: 100) do |product|
      begin
        service = Moysklad::SyncProductService.new(product, moysklad)
        result = service.call
        
        if result[:success]
          synced_count += 1
          puts "  ✅ Product ##{product.id} синхронизирован" if (synced_count % 100).zero?
        elsif result[:error_code] == 412
          error_412_count += 1
          puts "  ⚠️  Product ##{product.id} - ошибка 412 (дубликат code)" if (error_412_count % 10).zero?
        else
          error_count += 1
          puts "  ❌ Product ##{product.id} - ошибка: #{result[:error]}" if (error_count % 10).zero?
        end
      rescue StandardError => e
        error_count += 1
        Rails.logger.error "Moysklad sync error for product #{product.id}: #{e.message}"
        puts "  ❌ Product ##{product.id} - исключение: #{e.message}" if (error_count % 10).zero?
      end
    end

    puts "\n📊 Результаты синхронизации:"
    puts "  ✅ Успешно: #{synced_count}"
    puts "  ⚠️  Ошибка 412 (дубликат): #{error_412_count}"
    puts "  ❌ Другие ошибки: #{error_count}"
    puts "  📦 Всего обработано: #{synced_count + error_412_count + error_count} из #{total}"
  end
end

