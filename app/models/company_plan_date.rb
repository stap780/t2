class CompanyPlanDate < ApplicationRecord
  belongs_to :company
  has_many :comments, as: :commentable, dependent: :destroy
  accepts_nested_attributes_for :comments, allow_destroy: true

  validates :date, presence: true

  def self.human_attribute_name(attr, options = {})
    if attr.to_s == 'comments.body'
      I18n.t('activerecord.attributes.company_plan_date.comments.body', default: super)
    else
      super
    end
  end
end
