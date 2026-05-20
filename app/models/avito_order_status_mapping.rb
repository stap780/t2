# frozen_string_literal: true

class AvitoOrderStatusMapping < ApplicationRecord
  belongs_to :order_status

  validates :avito_status, presence: true
  validates :order_status_id, uniqueness: true
end
