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
  
  after_create_commit { broadcast_prepend_to 'incases' }
  after_update_commit { broadcast_replace_to 'incases' }
  after_destroy_commit { broadcast_remove_to 'incases' }
  # before_save :calculate_totalsum - это пока не нужно так как сумма первоначальная должна сохранятся
  before_create :set_default_status
  
  validates :date, presence: true
  validates :unumber, presence: true
  validate :items_presence
  
  REGION = %w[МСК СПБ].freeze

  attribute :strah_title
  attribute :company_title
  attribute :incase_status_title
  attribute :incase_tip_title

  def self.file_export_attributes
    attribute_names - ["strah_id","company_id","incase_status_id","incase_tip_id","created_at","updated_at"]
  end
  
  def self.ransackable_attributes(auth_object = nil)
    # attribute_names
    super
  end

  def self.ransackable_associations(auth_object = nil)
    %w[associated_audits audits company items strah incase_status incase_tip]
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

  def incase_status_title
    return '' unless incase_status.present?
    incase_status.title
  end
  
  def incase_tip_title
    return '' unless incase_tip.present?
    incase_tip.title
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

