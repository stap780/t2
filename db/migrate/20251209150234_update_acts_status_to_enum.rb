class UpdateActsStatusToEnum < ActiveRecord::Migration[8.0]
  def up
    # Обновляем существующие значения статусов с русских строк на enum значения
    execute <<-SQL
      UPDATE acts SET status = 'pending' WHERE status = 'Новый';
      UPDATE acts SET status = 'sent' WHERE status = 'Отправлен';
      UPDATE acts SET status = 'closed' WHERE status = 'Закрыт';
    SQL
    
    # Изменяем значение по умолчанию
    change_column_default :acts, :status, 'pending'
  end

  def down
    # Возвращаем русские значения
    execute <<-SQL
      UPDATE acts SET status = 'Новый' WHERE status = 'pending';
      UPDATE acts SET status = 'Отправлен' WHERE status = 'sent';
      UPDATE acts SET status = 'Закрыт' WHERE status = 'closed';
    SQL
    
    # Возвращаем старое значение по умолчанию
    change_column_default :acts, :status, 'Новый'
  end
end
