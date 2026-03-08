namespace :moysklad do
  desc "Создать товары со статусом pending без varbind Moysklad в МойСклад"
  task sync_pending_products: :environment do
    moysklad = Moysklad.first
    unless moysklad
      puts "❌ Конфигурация МойСклад не найдена"
      next
    end

    puts "🔄 Начало массового создания товаров в МойСклад"
    puts "⏰ Время сервера: #{Time.now}"
    puts "⏰ Московское время: #{Time.zone.now}"

    service = MoyskladApi::CreateProductsBatch.new(moysklad)
    result = service.call

    if result[:success]
      puts "\n📊 Результаты создания:"
      puts "  ✅ Создано: #{result[:created_count]}"
      puts "  ⚠️  Ошибка 412 (дубликат): #{result[:error_412_count]}"
      puts "  ❌ Другие ошибки: #{result[:error_count]}"
      puts "  📦 Всего обработано: #{result[:created_count] + result[:error_412_count] + result[:error_count]} из #{result[:total]}"
      puts "⏰ Время завершения: #{Time.zone.now}"
    else
      puts "❌ Ошибка создания: #{result[:error]}"
    end
  end

  desc "Обновить остатки товаров из МойСклад"
  task update_quantities: :environment do
    moysklad = Moysklad.first
    unless moysklad
      puts "❌ Конфигурация МойСклад не найдена"
      next
    end

    puts "🔄 Начало обновления остатков из МойСклад"
    puts "⏰ Время сервера: #{Time.now}"
    puts "⏰ Московское время: #{Time.zone.now}"

    service = MoyskladApi::UpdateQuantities.new(moysklad)
    result = service.call

    if result[:success]
      puts "✅ Обновление завершено успешно"
      puts "📊 Обновлено вариантов: #{result[:updated_count]}"
      puts "🏢 Обновлено складов (features): #{result[:stations_updated]}"
      puts "📦 Вариантов с остатком > 0: #{result[:with_quantity_count]}"
      puts "⏰ Время завершения: #{Time.zone.now}"
    else
      puts "❌ Ошибка обновления: #{result[:error]}"
    end
  end
end

