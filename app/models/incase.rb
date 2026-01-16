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

  private
  
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
  
end

