class Act < ApplicationRecord
  include NormalizeDataWhiteSpace
  include ActionView::RecordIdentifier
  audited
  
  belongs_to :company
  belongs_to :strah, class_name: 'Company', foreign_key: 'strah_id'
  belongs_to :okrug
  has_many :act_items, dependent: :destroy
  has_many :items, through: :act_items
  has_many :incases, -> { distinct }, through: :items
  
  validates :number, presence: true, uniqueness: true
  validates :date, presence: true
  validates :status, presence: true
  
  after_create_commit { broadcast_prepend_to 'acts' }
  after_update_commit { broadcast_replace_to 'acts' }
  
  STATUSES = %w[Новый Отправлен Закрыт].freeze
  
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[company strah okrug items act_items incases]
  end
  
  def totalsum
    items.sum(&:sum)
  end
end

