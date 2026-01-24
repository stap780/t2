namespace :test do
  desc "Test incase email sending - single and multiple"
  task incase_emails: :environment do
    puts "=" * 80
    puts "Тестирование отправки писем для убытков"
    puts "=" * 80
    
    # Находим убытки для тестирования
    incases = Incase.where(sendstatus: nil)
                    .includes(:company, :items)
                    .limit(5)
    
    if incases.empty?
      puts "❌ Не найдено убытков с sendstatus: nil для тестирования"
      puts "   Создайте убытки или сбросьте sendstatus для существующих"
      next
    end
    
    puts "\nНайдено убытков для тестирования: #{incases.count}"
    incases.each do |incase|
      puts "  - ID: #{incase.id}, Номер дела: #{incase.unumber}, Компания: #{incase.company&.short_title}"
    end
    
    # Группируем по компаниям
    companies = incases.group_by(&:company_id)
    puts "\nГруппировка по компаниям:"
    companies.each do |company_id, company_incases|
      company = Company.find(company_id)
      puts "  - #{company.short_title}: #{company_incases.count} убытков"
    end
    
    puts "\n" + "=" * 80
    puts "Тест 1: Групповая отправка всех найденных убытков"
    puts "=" * 80
    
    incase_ids = incases.pluck(:id)
    puts "Отправка убытков: #{incase_ids.join(', ')}"
    
    begin
      IncaseEmailService.send(incase_ids)
      puts "✅ Сервис вызван успешно"
      
      # Проверяем созданные EmailDelivery записи
      email_deliveries = EmailDelivery.where(status: 'pending')
                                      .order(created_at: :desc)
                                      .limit(companies.count)
      
      puts "\nСозданные EmailDelivery записи:"
      email_deliveries.each do |ed|
        metadata = ed.metadata || {}
        incase_ids_in_ed = metadata['incase_ids'] || []
        puts "  - ID: #{ed.id}, Компания: #{ed.recipient&.short_title}, Убытки: #{incase_ids_in_ed.join(', ')}, Статус: #{ed.status}"
      end
      
      puts "\n⚠️  Внимание: Jobs выполняются асинхронно через Solid Queue"
      puts "   Для проверки выполнения запустите: rails jobs:work"
      puts "   Или проверьте статус EmailDelivery записей через некоторое время"
      
    rescue => e
      puts "❌ Ошибка при отправке: #{e.class} - #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
    
    puts "\n" + "=" * 80
    puts "Тест 2: Проверка Excel файлов в EmailDelivery"
    puts "=" * 80
    
    # Ждем немного для выполнения jobs (если они выполняются синхронно в тестах)
    sleep 2 if Rails.env.test?
    
    email_deliveries = EmailDelivery.where(status: ['pending', 'sent'])
                                     .order(created_at: :desc)
                                     .limit(companies.count)
    
    email_deliveries.each do |ed|
      if ed.attachment.attached?
        puts "✅ EmailDelivery ##{ed.id}: Excel файл прикреплен (#{ed.attachment.filename})"
        
        # Проверяем содержимое Excel (если возможно)
        begin
          require 'caxlsx'
          require 'zip'
          
          blob = ed.attachment.blob
          blob.open do |file|
            # Пытаемся прочитать Excel
            package = Axlsx::Package.new
            # Это упрощенная проверка - просто проверяем наличие файла
            puts "   Размер файла: #{blob.byte_size} байт"
          end
        rescue => e
          puts "   ⚠️  Не удалось проверить содержимое Excel: #{e.message}"
        end
      else
        puts "❌ EmailDelivery ##{ed.id}: Excel файл НЕ прикреплен (статус: #{ed.status})"
        if ed.status == 'failed'
          puts "   Ошибка: #{ed.error_message}"
        end
      end
    end
    
    puts "\n" + "=" * 80
    puts "Рекомендации для полного тестирования:"
    puts "=" * 80
    puts "1. Запустите jobs: rails jobs:work (или дождитесь выполнения в фоне)"
    puts "2. Проверьте почту получателей (toweleie23@gmail.com, panaet80@gmail.com)"
    puts "3. Проверьте статус EmailDelivery записей в базе данных"
    puts "4. Проверьте, что sendstatus обновился на true для отправленных убытков"
    puts "=" * 80
  end
  
  desc "Test incase email sending with specific incase IDs"
  task :incase_emails_with_ids, [:incase_ids] => :environment do |t, args|
    incase_ids = args[:incase_ids].to_s.split(',').map(&:strip).map(&:to_i).reject(&:zero?)
    
    if incase_ids.empty?
      puts "❌ Укажите ID убытков через запятую: rake test:incase_emails_with_ids[1,2,3]"
      next
    end
    
    puts "Тестирование отправки писем для убытков: #{incase_ids.join(', ')}"
    
    begin
      IncaseEmailService.send(incase_ids)
      puts "✅ Сервис вызван успешно"
      
      email_deliveries = EmailDelivery.where(status: 'pending')
                                      .order(created_at: :desc)
                                      .limit(10)
      
      puts "\nСозданные EmailDelivery записи:"
      email_deliveries.each do |ed|
        metadata = ed.metadata || {}
        incase_ids_in_ed = metadata['incase_ids'] || []
        puts "  - ID: #{ed.id}, Компания: #{ed.recipient&.short_title}, Убытки: #{incase_ids_in_ed.join(', ')}"
      end
    rescue => e
      puts "❌ Ошибка: #{e.class} - #{e.message}"
      puts e.backtrace.first(5).join("\n")
    end
  end
  
  desc "Check email delivery status"
  task check_email_status: :environment do
    puts "=" * 80
    puts "Статус EmailDelivery записей"
    puts "=" * 80
    
    email_deliveries = EmailDelivery.order(created_at: :desc).limit(10)
    
    if email_deliveries.empty?
      puts "Нет записей EmailDelivery"
      next
    end
    
    email_deliveries.each do |ed|
      metadata = ed.metadata || {}
      incase_ids = metadata['incase_ids'] || []
      
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
      
      puts "#{status_icon} ID: #{ed.id} | Статус: #{ed.status} | Компания: #{ed.recipient&.short_title} | Убытки: #{incase_ids.join(', ')}"
      
      if ed.attachment.attached?
        puts "   📎 Excel: #{ed.attachment.filename} (#{ed.attachment.byte_size} байт)"
      else
        puts "   ⚠️  Excel файл не прикреплен"
      end
      
      if ed.error_message.present?
        puts "   ❌ Ошибка: #{ed.error_message}"
      end
      
      if ed.sent_at.present?
        puts "   📧 Отправлено: #{ed.sent_at.strftime('%d.%m.%Y %H:%M:%S')}"
      end
      
      puts ""
    end
  end
end
