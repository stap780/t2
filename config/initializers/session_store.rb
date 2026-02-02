# Хранилище сессии Rails в БД (таблица ar_sessions).
# Таблица sessions уже используется для сессий пользователей (user_id, ip_address и т.д.).
ActiveRecord::SessionStore::Session.table_name = "ar_sessions"
