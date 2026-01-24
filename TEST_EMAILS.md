# Инструкция по тестированию отправки писем

## Способы тестирования

### 1. Через Rake задачи

#### Тестирование с автоматическим поиском убытков:
```bash
rails test:incase_emails
```

Эта задача:
- Найдет до 5 убытков с `sendstatus: nil`
- Покажет группировку по компаниям
- Отправит письма для всех найденных убытков
- Покажет созданные EmailDelivery записи
- Проверит наличие Excel файлов

#### Тестирование с указанными ID убытков:
```bash
rails test:incase_emails_with_ids[1,2,3]
```

#### Проверка статуса отправленных писем:
```bash
rails test:check_email_status
```

### 2. Через Rails Runner (скрипт)

```bash
rails runner script/test_incase_emails.rb
```

### 3. Через Rails Console

```ruby
# Найти убытки для тестирования
incases = Incase.where(sendstatus: nil).limit(3)
incase_ids = incases.pluck(:id)

# Отправить письма
IncaseEmailService.send(incase_ids)

# Проверить созданные EmailDelivery записи
EmailDelivery.order(created_at: :desc).limit(5).each do |ed|
  puts "ID: #{ed.id}, Статус: #{ed.status}, Компания: #{ed.recipient&.short_title}"
  puts "  Excel прикреплен: #{ed.attachment.attached?}"
  puts "  Убытки: #{(ed.metadata || {})['incase_ids']}"
end
```

## Что проверять

### 1. Группировка по компаниям
- Убытки одной компании должны отправляться одним письмом
- Каждая компания получает отдельное письмо

### 2. Excel файл
- Должен быть прикреплен к EmailDelivery записи
- Должен содержать все позиции (items) из всех убытков
- Должна быть колонка "Статус детали"

### 3. Содержимое Excel
Проверьте, что в Excel есть:
- Контрагент
- Страховая компания
- Номер З/Н СТОА
- Номер дела
- Марка и Модель ТС
- Гос номер
- Деталь
- Статус детали

### 4. Отправка письма
- Письмо должно быть отправлено на адреса из `IncaseMailer` (toweleie23@gmail.com, panaet80@gmail.com)
- Статус EmailDelivery должен обновиться на `sent`
- `sendstatus` убытков должен обновиться на `true`

### 5. Групповая отправка при импорте
- При импорте нескольких убытков должно отправляться одно письмо на компанию
- Не должно быть множества отдельных писем

## Выполнение Jobs

Если используется асинхронная очередь (Solid Queue), запустите:

```bash
rails jobs:work
```

Или в отдельном терминале:
```bash
bundle exec rake solid_queue:start
```

## Проверка результатов

1. **В базе данных:**
   ```ruby
   # Проверить EmailDelivery записи
   EmailDelivery.order(created_at: :desc).limit(10)
   
   # Проверить обновление sendstatus
   Incase.where(sendstatus: true).count
   ```

2. **В почте:**
   - Проверьте почту toweleie23@gmail.com и panaet80@gmail.com
   - Должно прийти письмо с вложенным Excel файлом

3. **В логах:**
   - Проверьте логи Rails на наличие ошибок
   - Проверьте логи Solid Queue для jobs

## Возможные проблемы

### Excel файл пустой
- Проверьте, что у убытков есть items
- Проверьте логи GenerateIncaseExcelJob

### Письма не отправляются
- Проверьте настройки SMTP в `config/environments/development.rb`
- Проверьте credentials для SMTP пароля
- Проверьте логи IncaseEmailJob

### Jobs не выполняются
- Убедитесь, что Solid Queue запущен
- Проверьте статус jobs в базе данных
