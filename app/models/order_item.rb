# frozen_string_literal: true

class OrderItem < ApplicationRecord
  belongs_to :order
  belongs_to :variant, optional: true

  validates :quantity, numericality: { only_integer: true, greater_than: 0 }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  def line_sum
    return 0 if price.blank?

    quantity * price
  end
end
