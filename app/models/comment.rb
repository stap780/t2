class Comment < ApplicationRecord
  include ActionView::RecordIdentifier
  
  belongs_to :commentable, polymorphic: true
  belongs_to :user, optional: true
  
  validates :body, presence: true
end

