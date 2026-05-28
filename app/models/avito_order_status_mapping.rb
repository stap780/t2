# frozen_string_literal: true

class AvitoOrderStatusMapping < ApplicationRecord
  TRANSITIONS = %w[confirm reject perform receive].freeze

  belongs_to :avito
  belongs_to :order_status

  validates :avito_status, presence: true, inclusion: { in: TRANSITIONS }
  validates :order_status_id, uniqueness: { scope: :avito_id }
end
