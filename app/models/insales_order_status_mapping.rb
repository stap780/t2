# frozen_string_literal: true

class InsalesOrderStatusMapping < ApplicationRecord
  belongs_to :insale, optional: true
  belongs_to :order_status

  before_validation :normalize_insale_id

  validates :insales_status_key, presence: true
  validates :insales_status_key, uniqueness: { scope: :insale_id }
  validates :order_status_id, presence: true

  private

  def normalize_insale_id
    self.insale_id = nil if insale_id.blank?
  end
end
