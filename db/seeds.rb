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