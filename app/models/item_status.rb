class ItemStatus < ApplicationRecord
  include NormalizeDataWhiteSpace
  include ActionView::RecordIdentifier
  acts_as_list
  
  has_many :items
  
  after_create_commit { broadcast_prepend_to 'item_statuses' }
  after_update_commit { broadcast_replace_to 'item_statuses' }
  after_destroy_commit { broadcast_remove_to 'item_statuses' }
  
  validates :title, presence: true
  
  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end
end

