class Okrug < ApplicationRecord
  include NormalizeDataWhiteSpace
  include ActionView::RecordIdentifier
  acts_as_list
  
  has_many :companies
  has_many :acts
  
  validates :title, presence: true, uniqueness: true
  
  after_create_commit { broadcast_prepend_to 'okrugs' }
  after_update_commit { broadcast_replace_to 'okrugs' }
  after_destroy_commit { broadcast_remove_to 'okrugs' }
  
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end
  
  def self.ransackable_associations(auth_object = nil)
    %w[companies acts]
  end
end

