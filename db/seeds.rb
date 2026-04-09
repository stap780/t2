# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

user = User.find_or_initialize_by(email_address: "admin@example.com")
user.assign_attributes(password: "password", password_confirmation: "password")
user.save!

# Отделы — как в графике отпусков (Google Sheets «Отчет DA», колонка «Отдел»)
[
  "Руководители",
  "Приема товара",
  "Продажи и сервис",
  "Хранение",
  "Логистика"
].each do |name|
  Department.find_or_create_by!(name: name)
end

# Сотрудники — как в «Отчёт DA» (ФИО, роль → отдел, руководитель)
# Порядок: сначала руководители верхнего уровня, затем подчинённые (для manager_id).
dept = ->(name) { Department.find_by!(name: name) }
find_mgr = lambda do |full_name|
  full_name.present? ? Employee.find_by!(full_name: full_name) : nil
end

employees_rows = [
  # Аветисян в колонке «Руководитель» у первой группы, строкой в файле часто нет — добавляем как корень иерархии
  { full_name: "Аветисян Микаэл", department: "Руководители", manager: nil },
  { full_name: "Хренов Игорь", department: "Руководители", manager: "Аветисян Микаэл" },
  { full_name: "Матросов Саша", department: "Продажи и сервис", manager: "Аветисян Микаэл" },
  { full_name: "Зубанов Артём", department: "Приема товара", manager: "Аветисян Микаэл" },
  { full_name: "Жихарев Антон", department: "Руководители", manager: "Аветисян Микаэл" },
  { full_name: "Логинов Руслан", department: "Руководители", manager: "Аветисян Микаэл" },
  { full_name: "Расторгуев Юра", department: "Логистика", manager: "Хренов Игорь" },
  { full_name: "Ионов Коля", department: "Хранение", manager: "Хренов Игорь" },
  { full_name: "Сулайманов Кайрат", department: "Хранение", manager: "Хренов Игорь" },
  { full_name: "Абдухоликов Сидик", department: "Хранение", manager: "Хренов Игорь" },
  { full_name: "Пулатов Женя", department: "Хранение", manager: "Хренов Игорь" },
  { full_name: "Кудряшов Никита", department: "Хранение", manager: "Хренов Игорь" },
  { full_name: "Рамазонов Шухрат", department: "Хранение", manager: "Хренов Игорь" },
  { full_name: "Щуров Артём", department: "Логистика", manager: "Хренов Игорь" },
  { full_name: "Кетчина Елена", department: "Продажи и сервис", manager: "Жихарев Антон" },
  { full_name: "Зубанова Марина", department: "Продажи и сервис", manager: "Жихарев Антон" },
  { full_name: "Ежов Василий", department: "Продажи и сервис", manager: "Жихарев Антон" },
  { full_name: "Игайкин Саша", department: "Продажи и сервис", manager: "Жихарев Антон" },
  { full_name: "Кулаев Дима", department: "Продажи и сервис", manager: "Жихарев Антон" },
  { full_name: "Петроченко Юля", department: "Продажи и сервис", manager: "Жихарев Антон" },
  { full_name: "Шишкин Владимир", department: "Продажи и сервис", manager: "Жихарев Антон" },
  { full_name: "Викулин Влад", department: "Продажи и сервис", manager: "Жихарев Антон" },
  { full_name: "Алиев Рома", department: "Логистика", manager: "Логинов Руслан" },
  { full_name: "Мельников Юра", department: "Логистика", manager: "Логинов Руслан" },
  { full_name: "Алексей", department: "Приема товара", manager: "Логинов Руслан" },
  { full_name: "Шах", department: "Приема товара", manager: "Логинов Руслан" }
]

employees_rows.each do |row|
  manager_record = find_mgr.call(row[:manager])
  Employee.find_or_initialize_by(full_name: row[:full_name]).tap do |emp|
    emp.department = dept.call(row[:department])
    emp.manager = manager_record
    emp.save!
  end
end

# IncaseStatus (Статусы заявок)
incase_statuses = [
  { title: "Да", color: "#000000", position: 1 },
  { title: "Да (кроме отсутствовавших)", color: "#000000", position: 2 },
  { title: "Да (кроме стекла)", color: "#000000", position: 3 },
  { title: "Да (кроме отсутствовавших и стекла)", color: "#000000", position: 4 },
  { title: "Нет", color: "#000000", position: 5 },
  { title: "Нет (ДРМ)", color: "#000000", position: 6 },
  { title: "Нет (Срез)", color: "#000000", position: 7 },
  { title: "Нет (Стекло)", color: "#000000", position: 8 },
  { title: "Нет з/ч", color: "#000000", position: 9 },
  { title: "Нет (область)", color: "#000000", position: 10 },
  { title: "Частично", color: "#000000", position: 11 },
  { title: "Не ездили", color: "#000000", position: 12 },
  { title: "Да (кроме не запрашивать)", color: "#000000", position: 13 },
  { title: "Получено", color: "#000000", position: 14 },
  { title: "Не получены", color: "#000000", position: 15 },
  { title: "Долг", color: "#000000", position: 16 }
]

incase_statuses.each do |status_data|
  status = IncaseStatus.find_or_initialize_by(title: status_data[:title])
  status.assign_attributes(color: status_data[:color], position: status_data[:position])
  status.save!
end

# IncaseTip (Типы заявок)
incase_tips = [
  { title: "Просрочен", color: "#000000", position: 1 },
  { title: "Перепроверить", color: "#000000", position: 2 },
  { title: "Тотал", color: "#000000", position: 3 },
  { title: "Не согласовано", color: "#000000", position: 4 }
]

incase_tips.each do |tip_data|
  tip = IncaseTip.find_or_initialize_by(title: tip_data[:title])
  tip.assign_attributes(color: tip_data[:color], position: tip_data[:position])
  tip.save!
end

# ItemStatus (Статусы позиций)
item_statuses = [
  { title: "Да", color: "#000000", position: 1 },
  { title: "Нет (Отсутствовала)", color: "#000000", position: 2 },
  { title: "Долг", color: "#000000", position: 3 },
  { title: "В работе", color: "#000000", position: 4 },
  { title: "Нет (ДРМ)", color: "#000000", position: 5 },
  { title: "Нет (Срез)", color: "#000000", position: 6 },
  { title: "Нет (Стекло)", color: "#000000", position: 7 },
  { title: "Нет", color: "#000000", position: 8 },
  { title: "Нет (МО)", color: "#000000", position: 9 },
  { title: "Не запрашиваем", color: "#000000", position: 10 }
]

item_statuses.each do |status_data|
  status = ItemStatus.find_or_initialize_by(title: status_data[:title])
  status.assign_attributes(color: status_data[:color], position: status_data[:position])
  status.save!
end

# Виды дня (ShiftCode) — график работы и отпусков
[
  { code: "Al", label: "Рабочая смена", position: 1, color: "#22c55e", vacation: false, day_off: false },
  { code: "Vyx", label: "Выходной", position: 2, color: "#eab308", vacation: false, day_off: true },
  { code: "O", label: "Отпуск", position: 3, color: "#f97316", vacation: true, day_off: false },
  { code: "M5", label: "Смена М5", position: 4, color: "#64748b", vacation: false, day_off: false },
  { code: "B", label: "Больничный", position: 5, color: "#94a3b8", vacation: false, day_off: false }
].each do |row|
  ShiftCode.find_or_initialize_by(code: row[:code]).tap do |sc|
    sc.assign_attributes(row.except(:code))
    sc.save!
  end
end