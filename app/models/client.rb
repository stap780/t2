class Client < ApplicationRecord
  include NormalizeDataWhiteSpace
  include ActionView::RecordIdentifier

  has_many :client_companies
  has_many :companies, through: :client_companies
  
  validates :name, presence: true
  validates :email, presence: true
  validates :email, uniqueness: true

  before_destroy :check_relations_present, prepend: true

  after_create_commit { broadcast_append_to 'clients' }
  after_update_commit { broadcast_replace_to 'clients' }
  after_destroy_commit { broadcast_remove_to 'clients' }

  scope :first_five, -> { all.limit(5).map { |p| [p.full_name, p.id] } }
  scope :collection_for_select, ->(id) { where(id: id).map { |p| [p.full_name, p.id] } + first_five }

  def full_name
    [name, surname, email, phone].join(' ')
  end

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[companies client_companies]
  end

  private

  def check_relations_present
    if companies.count.positive?
      errors.add(:base, "Cannot delete Client. You have #{I18n.t('companies')} with it.")
    end

    throw(:abort) if errors.present?
  end
end
