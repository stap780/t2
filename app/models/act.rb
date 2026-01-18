class Act < ApplicationRecord
  include NormalizeDataWhiteSpace
  include ActionView::RecordIdentifier
  audited
  
  belongs_to :company
  belongs_to :strah, class_name: 'Company', foreign_key: 'strah_id'
  belongs_to :okrug
  belongs_to :driver, class_name: 'User', foreign_key: 'driver_id', optional: true
  has_many :act_items, dependent: :destroy
  has_many :items, through: :act_items
  has_many :incases, -> { distinct }, through: :items
  has_many :email_deliveries, as: :record, dependent: :destroy
  
  validates :date, presence: true
  validates :status, presence: true
  
  after_create :set_number_from_id
  after_create_commit { broadcast_prepend_to 'acts' }
  after_update_commit { broadcast_replace_to 'acts' }
  
  enum :status, {
    pending: 'pending',
    in_progress: 'in_progress',
    sent: 'sent',
    completed: 'completed',
    canceled: 'canceled',
    closed: 'closed'
  }
  
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[company strah okrug driver items act_items incases]
  end
  
  def totalsum
    items.sum(&:sum)
  end

  # Массовое создание актов из выбранных позиций
  def self.create_from_selected_items(act_datas)
    # Валидация наличия водителей
    validation_result = validate_drivers_for_companies(act_datas)
    puts "validation_result: #{validation_result.inspect}"
    return validation_result if validation_result[:error]

    # Группировка позиций
    grouped_data = group_items_by_company_strah_date_and_driver(act_datas)
    
    # Проверка, есть ли позиции для создания актов
    total_items = grouped_data.values.sum { |data| data[:items].count }
    puts "grouped_data keys: #{grouped_data.keys.inspect}"
    puts "total_items: #{total_items}"
    if total_items == 0
      return { error: true, message: "Не выбрано ни одной позиции" }
    end

    # Создание/обновление актов
    created_act_ids = create_or_update_from_grouped_data(grouped_data)

    { success: true, act_ids: created_act_ids.uniq }
  rescue => e
    Rails.logger.error("Act.create_from_selected_items error: #{e.class} #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    { error: true, message: e.message }
  end

  # Валидация наличия водителя для всех выбранных компаний
  def self.validate_drivers_for_companies(act_datas)
    companies_without_driver = []

    act_datas.each do |company_id, company_data|
      # Проверяем, есть ли выбранные позиции у компании
      # Валидируем driver_id только если есть выбранные позиции
      has_selected_items = false
      
      if company_data['incases'].present?
        company_data['incases'].each do |incase_id, incase_data|
          # Проверяем, выбрана ли заявка
          if incase_data['selected'] == '1'
            has_selected_items = true
            break
          end
          
          # Или есть выбранные позиции
          if incase_data['items'].present?
            incase_data['items'].each do |item_id, item_data|
              if item_data['selected'] == '1'
                has_selected_items = true
                break
              end
            end
            break if has_selected_items
          end
        end
      end
      
      # Если компания выбрана (через чекбокс) или есть выбранные позиции
      next unless company_data['id'] == '1' || has_selected_items

      driver_id = company_data['driver_id']
      if driver_id.blank? || driver_id.to_i == 0
        company = Company.find(company_id.to_i)
        companies_without_driver << company.short_title
      end
    end

    if companies_without_driver.any?
      {
        error: true,
        message: "Выберите водителя для компаний: #{companies_without_driver.join(', ')}"
      }
    else
      { error: false }
    end
  end

  # Группировка позиций по компании, страховой, дате и водителю
  def self.group_items_by_company_strah_date_and_driver(act_datas)
    items_by_company_strah_date_and_driver = {}

    act_datas.each do |company_id, company_data|
      # Пропускаем компании без данных или без выбранного чекбокса
      # Но если есть incases с данными, обрабатываем их
      has_data = company_data['incases'].present?
      next unless company_data['id'] == '1' || has_data # Компания выбрана или есть данные

      company = Company.find(company_id.to_i)
      okrug_id = company.okrug_id
      driver_id_raw = company_data['driver_id']
      driver_id = driver_id_raw.present? && driver_id_raw.to_i != 0 ? driver_id_raw.to_i : nil
      incases_data = company_data['incases'] || {}

      incases_data.each do |incase_id, incase_data|
        next unless incase_data['selected'] == '1' # Заявка выбрана

        incase = Incase.find(incase_id.to_i)
        items_data = incase_data['items'] || {}

        items_data.each do |item_id, item_data|
          next unless item_data['selected'] == '1' # Позиция выбрана

          item = Item.find(item_id.to_i)
          act_date = next_working_day

          # Ключ группировки: компания + страховая + дата + водитель
          key = "#{company_id}_#{incase.strah_id}_#{act_date.strftime('%Y-%m-%d')}_#{driver_id || 'nil'}"

          items_by_company_strah_date_and_driver[key] ||= {
            company_id: company_id.to_i,
            strah_id: incase.strah_id,
            date: act_date,
            okrug_id: okrug_id,
            driver_id: driver_id,
            items: []
          }
          items_by_company_strah_date_and_driver[key][:items] << item
        end
      end
    end

    items_by_company_strah_date_and_driver
  end

  # Создание или обновление актов из сгруппированных данных
  def self.create_or_update_from_grouped_data(grouped_data)
    created_act_ids = []

    grouped_data.each do |key, data|
      # Ищем существующий акт с такими же параметрами (включая driver_id)
      existing_act = find_by(
        company_id: data[:company_id],
        strah_id: data[:strah_id],
        date: data[:date],
        driver_id: data[:driver_id] || nil,
        status: :pending
      )

      if existing_act
        # Добавляем позиции к существующему акту
        data[:items].each do |item|
          ActItem.find_or_create_by!(act: existing_act, item: item)
        end
        created_act_ids << existing_act.id
      else
        # Создаем новый акт (номер будет установлен автоматически через after_create)
        new_act = create!(
          company_id: data[:company_id],
          strah_id: data[:strah_id],
          okrug_id: data[:okrug_id],
          date: data[:date],
          driver_id: data[:driver_id],
          status: :pending
        )

        # Связываем позиции с актом
        data[:items].each do |item|
          ActItem.create!(act: new_act, item: item)
        end
        created_act_ids << new_act.id
      end
    end

    created_act_ids
  end

  # Вычисление следующего рабочего дня (понедельник-пятница)
  def self.next_working_day(date = Date.current)
    result_date = date
    result_date = result_date.advance(days: 1) while result_date.saturday? || result_date.sunday?
    result_date
  end
  
  # Генерация PDF для акта
  def generate_pdf
    ActPdfService.new(self).call
  end
  
  
  private
  
  def set_number_from_id
    # Устанавливаем номер акта равным ID после создания
    # Используем update_column чтобы избежать валидаций и колбэков
    update_column(:number, id.to_s) if id.present?
  end
end

