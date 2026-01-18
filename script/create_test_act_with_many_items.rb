#!/usr/bin/env ruby
# Скрипт для создания тестового акта с большим количеством позиций
# Использование: rails runner script/create_test_act_with_many_items.rb [количество_позиций]

require_relative '../config/environment'

items_count = (ARGV[0] || 35).to_i

puts "=" * 80
puts "Создание тестового акта с #{items_count} позициями"
puts "=" * 80

# Находим или создаем необходимые данные
company = Company.first || Company.create!(
  title: "Тестовая компания",
  ur_address: "г. Москва, ул. Тестовая, д. 1"
)

strah = Company.where.not(id: company.id).first || Company.create!(
  title: "Страховая компания",
  ur_address: "г. Москва, ул. Страховая, д. 2"
)

okrug = Okrug.first || Okrug.create!(title: "Тестовый округ")

# Создаем тестовый акт
act = Act.create!(
  company: company,
  strah: strah,
  okrug: okrug,
  date: Date.current,
  status: :pending
)

puts "\nСоздан акт ##{act.id}"

# Создаем заявку (incase) с первой позицией через nested attributes
# Incase требует хотя бы одну позицию при создании
first_item_attrs = {
  title: "Тестовая позиция 1 - Деталь/Узел/Агрегат для проверки переноса страниц в PDF",
  katnumber: "КАТ-1",
  quantity: 1,
  price: 100.0,
  condition: :priemka
}

incase = Incase.create!(
  stoanumber: "ЗН-ТЕСТ-#{Time.current.to_i}",
  modelauto: "Тестовая модель",
  carnumber: "А123БВ777",
  unumber: "ВД-ТЕСТ-#{Time.current.to_i}",
  date: Date.current,
  company: company,
  strah: strah,
  items_attributes: [first_item_attrs]
)

puts "Создана заявка ##{incase.id} с первой позицией"

# Связываем первую позицию с актом
ActItem.create!(act: act, item: incase.items.first)
items_created = 1

# Создаем остальные позиции
puts "\nСоздание оставшихся #{items_count - 1} позиций..."

(items_count - 1).times do |i|
  item = Item.create!(
    incase: incase,
    title: "Тестовая позиция #{i + 2} - Деталь/Узел/Агрегат для проверки переноса страниц в PDF",
    katnumber: "КАТ-#{i + 2}",
    quantity: 1,
    price: 100.0 + ((i + 1) * 10),
    condition: :priemka
  )
  
  ActItem.create!(act: act, item: item)
  items_created += 1
  
  # Показываем прогресс каждые 10 позиций
  if (i + 2) % 10 == 0
    puts "  Создано #{i + 2}/#{items_count} позиций..."
  end
end

puts "✅ Создано #{items_created} позиций"

# Перезагружаем акт с позициями
act.reload

puts "\n" + "=" * 80
puts "ИТОГИ:"
puts "=" * 80
puts "Акт ID: #{act.id}"
puts "Компания: #{act.company.title}"
puts "Страховая: #{act.strah.title}"
puts "Количество позиций: #{act.items.count}"
puts "Количество заявок: #{act.incases.count}"

# Оцениваем количество страниц
estimated_height = 200  # Шапка и заголовки
act.incases.each do |inc|
  estimated_height += 30  # Заголовок заявки
  act.items.where(incase: inc).each do |item|
    estimated_height += 25  # Каждая позиция
  end
end

available_height = 812 - 35  # Минус место для футера
estimated_pages = (estimated_height.to_f / available_height).ceil

puts "Ожидаемое количество страниц: ~#{estimated_pages}"

puts "\n" + "=" * 80
puts "Для генерации PDF выполните:"
puts "  rails runner script/test_pdf.rb #{act.id}"
puts "=" * 80
