#!/usr/bin/env ruby
# Скрипт для тестирования генерации PDF с большим количеством позиций
# Использование: rails runner script/test_pdf.rb [act_id]

require_relative '../config/environment'

act_id = ARGV[0]&.to_i

if act_id
  act = Act.includes(:items, :company, :strah, items: :incase).find_by(id: act_id)
  unless act
    puts "❌ Акт с ID #{act_id} не найден"
    exit 1
  end
else
  # Сначала пробуем найти акт с ID 4 (как в примере act_4.pdf)
  act = Act.includes(:items, :company, :strah, items: :incase).find_by(id: 4)
  
  # Если не найден, берем последний акт
  act ||= Act.includes(:items, :company, :strah, items: :incase).order(id: :desc).first
  
  unless act
    puts "❌ Не найден ни один акт"
    puts "Создайте акт через интерфейс или используйте: rails runner script/test_pdf.rb ACT_ID"
    exit 1
  end
end

puts "=" * 80
puts "Тестирование генерации PDF для акта ##{act.id}"
puts "=" * 80
puts "\nИнформация об акте:"
puts "  Компания: #{act.company&.title}"
puts "  Страховая: #{act.strah&.title}"
puts "  Дата: #{act.date}"
puts "  Количество позиций: #{act.items.count}"
puts "  Количество заявок: #{act.incases.count}"

# Подсчитываем примерную высоту контента
estimated_height = 0
estimated_height += 200  # Шапка и заголовки
act.incases.each do |incase|
  estimated_height += 30  # Заголовок заявки
  act.items.where(incase: incase).each do |item|
    estimated_height += 25  # Каждая позиция
  end
end

# Высота страницы A4 минус отступы: 842 - 30 = 812 точек доступно
# Футер начинается на высоте 35 от низа, margin bottom = 15
# Значит футер начинается на высоте 20 от bounds.bottom
available_height = 812 - 35  # Минус место для футера
estimated_pages = (estimated_height.to_f / available_height).ceil

puts "  Примерная высота контента: ~#{estimated_height} точек"
puts "  Ожидаемое количество страниц: ~#{estimated_pages}"

puts "\nГенерация PDF..."
start_time = Time.current

begin
  pdf_data = ActPdfService.new(act).call
  
  if pdf_data.nil?
    puts "❌ Ошибка: PDF не был сгенерирован"
    exit 1
  end
  
  generation_time = Time.current - start_time
  
  # Сохраняем PDF
  output_path = Rails.root.join("tmp", "test_act_#{act.id}_#{Time.current.to_i}.pdf")
  File.binwrite(output_path, pdf_data)
  
  file_size = File.size(output_path)
  
  puts "✅ PDF успешно сгенерирован за #{generation_time.round(2)} секунд"
  puts "📄 Файл сохранен: #{output_path}"
  puts "📊 Размер файла: #{(file_size / 1024.0).round(2)} KB"
  
  # Пытаемся определить количество страниц через анализ PDF
  # Простой способ - искать маркеры страниц в бинарных данных
  page_count = pdf_data.scan(/\/Count\s+(\d+)/).flatten.map(&:to_i).max || 1
  puts "📑 Количество страниц в PDF: #{page_count}"
  
  puts "\n" + "=" * 80
  puts "ПРОВЕРКА:"
  puts "=" * 80
  puts "Откройте файл и убедитесь что:"
  puts "  ✅ Позиции НЕ накладываются на подписи в футере"
  puts "  ✅ При нехватке места создаются новые страницы"
  puts "  ✅ Футер с подписями виден на всех страницах"
  puts "  ✅ Подписи находятся на высоте ~35 точек от низа страницы"
  
  # Пытаемся открыть файл (только на macOS/Linux)
  if RUBY_PLATFORM.include?('darwin')
    puts "\nОткрываю PDF..."
    system("open '#{output_path}'")
  elsif RUBY_PLATFORM.include?('linux')
    puts "\nПопытка открыть PDF..."
    system("xdg-open '#{output_path}' 2>/dev/null || echo 'Установите программу для просмотра PDF'")
  end
  
rescue => e
  puts "❌ Ошибка при генерации PDF: #{e.message}"
  puts "\nТрассировка:"
  puts e.backtrace.first(10).join("\n")
  exit 1
end
