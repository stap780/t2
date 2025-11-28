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
  
  after_create_commit { broadcast_prepend_to 'incases' }
  after_update_commit { broadcast_replace_to 'incases' }
  after_destroy_commit { broadcast_remove_to 'incases' }
  # before_save :calculate_totalsum - это пока не нужно так как сумма первоначальная должна сохранятся
  
  validates :date, presence: true
  validates :unumber, presence: true
  validate :items_presence
  
  REGION = %w[МСК СПБ].freeze
  
  def self.ransackable_attributes(auth_object = nil)
    # attribute_names
    super
  end

  def self.ransackable_associations(auth_object = nil)
    %w[associated_audits audits company items strah incase_status incase_tip]
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

