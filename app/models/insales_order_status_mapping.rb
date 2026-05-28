# frozen_string_literal: true

class InsalesOrderStatusMapping < ApplicationRecord
  FINANCIAL_STATUSES = %w[pending paid].freeze

  belongs_to :insale
  belongs_to :order_status

  validates :insales_custom_status_permalink, presence: true
  validates :insales_financial_status, presence: true, inclusion: { in: FINANCIAL_STATUSES }
  validates :insales_custom_status_permalink,
            uniqueness: { scope: %i[insale_id insales_financial_status] }
  validates :order_status_id, presence: true
end
