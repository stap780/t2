class Comment < ApplicationRecord
  include ActionView::RecordIdentifier
  
  belongs_to :commentable, polymorphic: true
  belongs_to :user, optional: true
  
  validates :body, presence: true

  def self.human_attribute_name(attr, options = {})
    if attr.to_s == 'body'
      I18n.t('activerecord.attributes.comment.body', default: super)
    else
      super
    end
  end
end

