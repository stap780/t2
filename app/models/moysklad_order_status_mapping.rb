# frozen_string_literal: true

class MoyskladOrderStatusMapping < ApplicationRecord
  belongs_to :order_status

  validates :moysklad_state_href, presence: true, uniqueness: true
  validates :order_status_id, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[order_status]
  end
end
