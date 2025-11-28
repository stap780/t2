class ChangeAuditedChangesToJsonb < ActiveRecord::Migration[8.0]
  def up
    # Конвертируем существующие YAML данные в JSON через Ruby
    if table_exists?(:audits) && column_exists?(:audits, :audited_changes)
      # Получаем все записи с данными
      connection.execute("SELECT id, audited_changes FROM audits WHERE audited_changes IS NOT NULL AND audited_changes != ''").each do |row|
        id = row['id']
        yaml_data = row['audited_changes']
        
        begin
          # Пытаемся распарсить как YAML (разрешаем BigDecimal и другие типы)
          parsed_data = YAML.safe_load(yaml_data, permitted_classes: [BigDecimal, ActiveSupport::TimeWithZone, Time, Date, DateTime, Symbol])
          # Конвертируем в JSON строку
          json_data = parsed_data.to_json
          # Обновляем запись безопасно
          connection.execute("UPDATE audits SET audited_changes = #{connection.quote(json_data)}::jsonb WHERE id = #{id}")
        rescue => e
          # Если не удалось распарсить YAML, пытаемся как JSON
          begin
            connection.execute("UPDATE audits SET audited_changes = #{connection.quote(yaml_data)}::jsonb WHERE id = #{id}")
          rescue
            # Если и это не работает, очищаем поле
            connection.execute("UPDATE audits SET audited_changes = NULL WHERE id = #{id}")
          end
        end
      end
    end
    
    # Изменяем тип колонки с text на jsonb
    # Если данные уже NULL или пустые, они останутся NULL
    change_column :audits, :audited_changes, :jsonb, using: 
      "CASE 
        WHEN audited_changes IS NULL OR audited_changes = '' THEN NULL::jsonb
        ELSE audited_changes::jsonb
      END"
  end

  def down
    # Возвращаем обратно к text
    change_column :audits, :audited_changes, :text, using: 'audited_changes::text'
  end
end
