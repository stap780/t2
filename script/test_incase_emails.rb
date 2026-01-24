#!/usr/bin/env ruby
# Скрипт для тестирования отправки писем убытков
# Использование: rails runner script/test_incase_emails.rb

puts "=" * 80
puts "Тестирование отправки писем для убытков"
puts "=" * 80

# Находим убытки для тестирования
incases = Incase.where(sendstatus: nil)
                .includes(:company, :items, :item_status)
                .limit(5)

if incases.empty?
  puts "❌ Не найдено убытков с sendstatus: nil для тестирования"
  puts "   Создайте убытки или сбросьте sendstatus для существующих"
  exit
end

puts "\nНайдено убытков для тестирования: #{incases.count}"
incases.each do |incase|
  items_count = incase.items.count
  puts "  - ID: #{incase.id}, Номер дела: #{incase.unumber}, Компания: #{incase.company&.short_title}, Позиций: #{items_count}"
end

# Группируем по компаниям
companies = incases.group_by(&:company_id)
puts "\nГруппировка по компаниям:"
companies.each do |company_id, company_incases|
  company = Company.find(company_id)
  puts "  - #{company.short_title}: #{company_incases.count} убытков"
end

puts "\n" + "=" * 80
puts "Тест: Групповая отправка всех найденных убытков"
puts "=" * 80

incase_ids = incases.pluck(:id)
puts "Отправка убытков: #{incase_ids.join(', ')}"

begin
  IncaseEmailService.send(incase_ids)
  puts "✅ Сервис вызван успешно"
  
  # Ждем немного для выполнения jobs
  puts "\nОжидание выполнения jobs..."
  sleep 3
  
  # Проверяем созданные EmailDelivery записи
  email_deliveries = EmailDelivery.where(status: ['pending', 'sent', 'failed'])
                                  .order(created_at: :desc)
                                  .limit(companies.count)
  
  puts "\nEmailDelivery записи:"
  email_deliveries.each do |ed|
    metadata = ed.metadata || {}
    incase_ids_in_ed = metadata['incase_ids'] || []
    
    status_icon = case ed.status
    when 'sent'
      '✅'
    when 'failed'
      '❌'
    when 'pending'
      '⏳'
    else
      '❓'
    end
    
    puts "#{status_icon} ID: #{ed.id} | Статус: #{ed.status} | Компания: #{ed.recipient&.short_title} | Убытки: #{incase_ids_in_ed.join(', ')}"
    
    if ed.attachment.attached?
      puts "   📎 Excel: #{ed.attachment.filename} (#{ed.attachment.byte_size} байт)"
      
      # Проверяем содержимое Excel
      begin
        require 'caxlsx'
        require 'zip'
        
        blob = ed.attachment.blob
        puts "   ✅ Файл прикреплен и доступен"
      rescue => e
        puts "   ⚠️  Ошибка при проверке файла: #{e.message}"
      end
    else
      puts "   ⚠️  Excel файл НЕ прикреплен"
    end
    
    if ed.error_message.present?
      puts "   ❌ Ошибка: #{ed.error_message}"
    end
    
    if ed.sent_at.present?
      puts "   📧 Отправлено: #{ed.sent_at.strftime('%d.%m.%Y %H:%M:%S')}"
    end
    
    puts ""
  end
  
  puts "\n" + "=" * 80
  puts "Проверка обновления sendstatus:"
  puts "=" * 80
  
  updated_incases = Incase.where(id: incase_ids, sendstatus: true)
  if updated_incases.any?
    puts "✅ Обновлено sendstatus для #{updated_incases.count} убытков:"
    updated_incases.each do |incase|
      puts "   - ID: #{incase.id}, Номер дела: #{incase.unumber}"
    end
  else
    puts "⏳ sendstatus еще не обновлен (jobs могут выполняться асинхронно)"
  end
  
rescue => e
  puts "❌ Ошибка при отправке: #{e.class} - #{e.message}"
  puts e.backtrace.first(10).join("\n")
end

puts "\n" + "=" * 80
puts "Рекомендации:"
puts "=" * 80
puts "1. Если jobs выполняются асинхронно, запустите: rails jobs:work"
puts "2. Проверьте почту получателей (toweleie23@gmail.com, panaet80@gmail.com)"
puts "3. Проверьте статус через: rake test:check_email_status"
puts "=" * 80
