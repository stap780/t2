class Incase < ApplicationRecord
  include NormalizeDataWhiteSpace
  include ActionView::RecordIdentifier
  audited
  has_associated_audits
  
  belongs_to :incase_status, optional: true
  belongs_to :incase_tip, optional: true
  belongs_to :company
  belongs_to :strah, class_name: 'Company', foreign_key: 'strah_id'
  has_many :items, -> { order(:id) }, dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  has_many :comments, as: :commentable, dependent: :destroy
  accepts_nested_attributes_for :comments, allow_destroy: true
  has_many :email_deliveries, as: :record, dependent: :destroy
  
  # after_create_commit { broadcast_prepend_to 'incases' }
  after_update_commit { broadcast_replace_to 'incases' }
  after_destroy_commit { broadcast_remove_to 'incases' }
  # before_save :calculate_totalsum - это пока не нужно так как сумма первоначальная должна сохранятся
  before_create :set_default_status
  before_destroy :check_items_not_in_acts, prepend: true
  

  validates :date, presence: true
  validates :unumber, presence: true
  validate :items_presence
  
  REGION = %w[МСК СПБ].freeze

  attribute :strah_title
  attribute :company_title
  attribute :company_contacts_data
  attribute :incase_status_title
  attribute :incase_tip_title

  def self.file_export_attributes
    # Базовый порядок колонок для экспорта
    base = %w[
      unumber          # Номер убытка
      stoanumber       # Номер з/н
      strah_title      # СК
      company_title    # СТО
      modelauto        # модель а/м
      carnumber        # номер а/м
      date             # дата
      totalsum         # сумма
      incase_status_title # статус убытка
      incase_tip_title    # тип
    ]

    attrs = attribute_names - %w[region sendstatus company_contacts_data id strah_id company_id incase_status_id incase_tip_id created_at updated_at]

    # Сначала атрибуты в нужном порядке, затем остальные
    (base & attrs) + (attrs - base)
  end
  
  def self.ransackable_attributes(auth_object = nil)
    super + %w[totalsum_blank]
  end

  # Ransacker для фильтра «Без суммы»: totalsum IS NULL OR totalsum = 0
  ransacker :totalsum_blank do
    Arel.sql("(#{table_name}.totalsum IS NULL OR #{table_name}.totalsum = 0)")
  end

  def self.ransackable_associations(auth_object = nil)
    %w[associated_audits audits company items strah incase_status incase_tip]
  end

  # Поиск убытка по паре (unumber, stoanumber). Пустой stoanumber (nil, '') считаем одним значением.
  def self.find_by_unumber_and_stoanumber(unumber, stoanumber)
    return nil if unumber.blank?
    normalized_sto = stoanumber.to_s.strip.presence
    if normalized_sto.nil?
      where(unumber: unumber).where(stoanumber: [nil, '']).first
    else
      find_by(unumber: unumber, stoanumber: normalized_sto)
    end
  end

  scope :unsent, -> { where(sendstatus: nil) }

  def sent?
    sendstatus == true
  end

  def strah_title
    return '' unless strah.present?
    strah.title
  end

  def company_title
    return '' unless company.present?
    company.title
  end

  def company_contacts_data
    return '' unless company.present?
    company.contacts_data
  end

  def incase_status_title
    return '' unless incase_status.present?
    incase_status.title
  end
  
  def incase_tip_title
    return '' unless incase_tip.present?
    incase_tip.title
  end

  def item_prices
    Rails.logger.info 'start calc_price'
    errors = []

    total = totalsum.present? ? totalsum.to_f : 0.0
    if total <= 0
      message = 'Сумма убытка не задана или равна нулю'
      errors << message
      Rails.logger.info(message)
      return [false, errors.join('. ')]
    end

    procent = strah&.rate.present? ? strah.rate.to_f / 100.0 : 1.0
    real_total = total * procent

    work_items = []
    not_use_statuses = ['Долг', 'Нет (Отсутствовала)', 'Нет (ДРМ)', 'Нет (Срез)', 'Нет (Стекло)', 'Нет', 'Не запрашиваем']

    items.includes(:item_status, :variant).each do |item|
      status_title = item.item_status&.title

      if item.variant&.price.present?
        work_items << {
          item: item,
          variant: item.variant,
          sell_price: item.variant.price.to_f
        }
      elsif status_title.present? && not_use_statuses.include?(status_title)
        work_items << {
          item: item,
          variant: item.variant,
          sell_price: 0.0
        }
      else
        msg = "Позиция ##{item.id} без цены и без подходящего статуса"
        errors << msg
        Rails.logger.info(msg)
      end
    end

    if work_items.size != items.size
      return [false, errors.join('. ')]
    end

    work_items_total = work_items.sum { |wi| wi[:sell_price] }

    ActiveRecord::Base.transaction do
      work_items.each do |wi|
        sell_price = wi[:sell_price]
        dolya = sell_price.to_i != 0 && work_items_total.positive? ? (sell_price * 100.0 / work_items_total) : 0.0
        price = real_total * dolya / 100.0

        wi[:item].update!(price: price)

        if wi[:variant].present?
          wi[:variant].update!(cost_price: price)
        end
      end

      work_items.each do |wi|
        next unless wi[:variant].present?

        variant = wi[:variant]
        product = variant.product
        next unless product.present?

        moysklad = Moysklad.first
        next unless moysklad.present?

        begin
          Moysklad::SyncProductService.new(product, moysklad).call
        rescue => e
          Rails.logger.error "Failed to sync product #{product.id} to Moysklad: #{e.message}"
        end
      end
    end

    [true, 'Проставили цены позициям']
  ensure
    Rails.logger.info 'finish calc_price'
  end

  def self.recalculate_status_from_items(incase_id)
    incase = find_by(id: incase_id)
    return unless incase
    
    # Собираем все статусы деталей убытка
    item_status_titles = incase.items.includes(:item_status)
      .map { |item| item.item_status&.title }
      .compact
    
    return if item_status_titles.empty?
    
    # Вычисляем статус убытка на основе логики из carpats
    new_status_title = calculate_incase_status(item_status_titles)
    
    # Находим IncaseStatus по названию и устанавливаем
    if new_status_title.present?
      incase_status = IncaseStatus.find_by(title: new_status_title)
      incase.update_column(:incase_status_id, incase_status.id) if incase_status
    end
  end

  private
  
  def set_default_status
    return if incase_status_id.present?
    
    # Устанавливаем статус "Не ездили" для нового убытка, если статус не указан
    ne_ezdili_status = IncaseStatus.find_by(title: 'Не ездили')
    self.incase_status_id = ne_ezdili_status.id if ne_ezdili_status
  end

  def check_items_not_in_acts
    return unless ActItem.where(item_id: items.select(:id)).exists?
    errors.add(:base, I18n.t('activerecord.errors.models.incase.items_in_acts'))
    throw(:abort)
  end
  
  def calculate_totalsum
    self.totalsum = items.sum(&:sum)
  end
  
  def items_presence
    # Проверяем, что есть хотя бы одна позиция (item)
    # Учитываем как новые записи (items), так и вложенные атрибуты (items_attributes)
    items_to_check = items.reject(&:marked_for_destruction?)
    
    if items_to_check.empty?
      errors.add(:base, I18n.t('activerecord.errors.models.incase.items_required'))
    end
  end

  def self.calculate_incase_status(item_status_titles)
    array = item_status_titles.uniq
    
    # Если есть "Да"
    if array.include?('Да')
      # Сначала проверяем специальные случаи (до проверки на "Частично")
      # Специальный случай: "Да" + "Нет (Стекло)" + "Нет (Отсутствовала)" без "Нет" и "Долг"
      if array.include?('Нет (Стекло)') && array.include?('Нет (Отсутствовала)')
        a2 = ['Нет', 'Долг']
        return 'Да (кроме отсутствовавших и стекла)' unless array.any? { |e| a2.include?(e) }
      end
      
      # Специальный случай: "Да" + "Нет (Стекло)" без "Нет" и "Нет (Отсутствовала)"
      if array.include?('Нет (Стекло)')
        a2 = ['Нет', 'Нет (Отсутствовала)']
        return 'Да (кроме стекла)' unless array.any? { |e| a2.include?(e) }
      end
      
      # Специальный случай: "Да" + "Нет (Отсутствовала)" без "Нет" и "Долг"
      if array.include?('Нет (Отсутствовала)')
        a2 = ['Нет', 'Долг']
        return 'Да (кроме отсутствовавших)' unless array.any? { |e| a2.include?(e) }
      end
      
      # Специальный случай: "Да" + "Не запрашиваем" без "В работе", "Нет", "Долг"
      if array.include?('Не запрашиваем')
        a2 = ['В работе', 'Нет', 'Долг']
        return 'Да (кроме не запрашивать)' unless array.any? { |e| a2.include?(e) }
      end
      
      # Теперь проверяем общие случаи
      a2 = ['Нет', 'Долг', 'Нет (Отсутствовала)', 'Нет (Стекло)', 'Не запрашиваем']
      return 'Да' unless array.any? { |e| a2.include?(e) }
      
      a2_chastichno = ['Нет', 'Долг', 'Нет (Отсутствовала)', 'В работе']
      return 'Частично' if array.any? { |e| a2_chastichno.include?(e) }
    end
    
    # Если есть "Нет"
    if array.include?('Нет')
      a2 = ['Да', 'Долг']
      return 'Нет' unless array.any? { |e| a2.include?(e) }
      # Если есть конфликт, возвращаем "Частично"
      return 'Частично'
    end
    
    # Если есть "Долг"
    if array.include?('Долг')
      return 'Долг' unless array.include?('Да')
      # Если есть "Да", возвращаем "Частично"
      return 'Частично'
    end
    
    # Проверки на одинаковые статусы
    return 'Не ездили' if array.all? { |e| e == 'В работе' }
    return 'Нет (ДРМ)' if array.all? { |e| e == 'Нет (ДРМ)' }
    return 'Нет (Срез)' if array.all? { |e| e == 'Нет (Срез)' }
    return 'Нет (Стекло)' if array.all? { |e| e == 'Нет (Стекло)' }
    return 'Нет з/ч' if array.all? { |e| e == 'Нет (Отсутствовала)' }
    return 'Не запрашиваем' if array.all? { |e| e == 'Не запрашиваем' }
    return 'Нет (область)' if array.all? { |e| e == 'Нет (МО)' }
    
    # Если все статусы nil или пустые
    return 'Не ездили' if array.all?(&:nil?)
    
    # По умолчанию - если разные статусы
    'Частично'
  end
  
end

