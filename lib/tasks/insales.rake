# frozen_string_literal: true

namespace :insales do
  desc "Синхронизация varbind: получить варианты из InSales API по всем 4 ключам, найти в БД по штрихкоду, добавить связь varbind"
  task varbind_sync: :environment do
    puts "🔄 Синхронизация varbind InSales (4 ключа)"
    puts "⏰ Время начала: #{Time.zone.now}"

    unless Insale.first
      puts "❌ Нет записи Insale в базе. Создайте и настройте Insale."
      next
    end

    result = Insales::VarbindSyncService.new.call

    if result[:success]
      puts "\n📊 Итого:"
      puts "   Обработано вариантов из API: #{result[:processed]}"
      puts "   Создано varbind (Variant): #{result[:created]}"
      puts "   Создано varbind (Product): #{result[:product_created]}"
      puts "   Пропущено (уже есть varbind): #{result[:skipped]}"
      puts "   Пропущено Product (уже есть varbind): #{result[:product_skipped]}"
      puts "   Не найдено в БД по штрихкоду: #{result[:not_found]}"
      puts "   Ошибок: #{result[:errors]}"
    else
      puts "❌ Ошибка: #{result[:error]}"
    end

    puts "⏰ Время завершения: #{Time.zone.now}"
  end

  desc "Обновить цену и количество в InSales по varbind через variants_group_update"
  task prices_update: :environment do
    puts "🔄 Обновление цен и остатков в InSales (variants_group_update)"
    puts "⏰ Время начала: #{Time.zone.now}"

    unless Insale.first
      puts "❌ Нет записи Insale в базе. Создайте и настройте Insale."
      next
    end

    result = Insales::PricesUpdateService.new.call

    if result[:success]
      puts "\n📊 Итого: обновлено #{result[:updated]} из #{result[:total]} вариантов"
    else
      puts "❌ Ошибка: #{result[:error]}"
    end

    puts "⏰ Время завершения: #{Time.zone.now}"
  end

  desc "Синхронизация изображений: товары InSales без фото (updated_since N дней) — добавить из приложения"
  task images_sync: :environment do
    puts "🔄 Синхронизация изображений InSales"
    puts "⏰ Время начала: #{Time.zone.now}"

    unless Insale.first
      puts "❌ Нет записи Insale в базе. Создайте и настройте Insale."
      next
    end

    days_back = (ENV["DAYS"] || 3).to_i
    result = Insales::ImagesSyncService.new(days_back: days_back).call

    if result[:success]
      puts "\n📊 Итого:"
      puts "   Обработано товаров: #{result[:processed]}"
      puts "   Добавлено изображений: #{result[:images_added]}"
      puts "   Пропущено (уже есть фото): #{result[:skipped]}"
      puts "   Не найдено в БД (нет varbind): #{result[:not_found]}"
      puts "   Ошибок: #{result[:errors]}"
    else
      puts "❌ Ошибка: #{result[:error]}"
    end

    puts "⏰ Время завершения: #{Time.zone.now}"
  end
end

# rails insales:varbind_sync
# rails insales:prices_update
# rails insales:images_sync
# DAYS=7 rails insales:images_sync  # за последние 7 дней
