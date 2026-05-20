# frozen_string_literal: true

class Order < ApplicationRecord
  include NormalizeDataWhiteSpace

  SOURCES = %w[avito insales moysklad].freeze

  belongs_to :client, optional: true
  belongs_to :order_status, optional: true
  belongs_to :avito, optional: true
  belongs_to :insale, optional: true

  has_many :order_items, dependent: :destroy
  accepts_nested_attributes_for :order_items, allow_destroy: true

  validates :source, presence: true, inclusion: { in: SOURCES }
  validates :avito_order_id, uniqueness: { scope: :avito_id }, allow_nil: true
  validates :insales_order_id, uniqueness: { scope: :insale_id }, allow_nil: true
  validates :moysklad_order_id, uniqueness: true, allow_nil: true

  scope :from_avito, -> { where(source: "avito") }
  scope :from_insales, -> { where(source: "insales") }
  scope :from_moysklad, -> { where(source: "moysklad") }

  def self.ransackable_attributes(_auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(_auth_object = nil)
    %w[client order_status order_items avito insale]
  end

  def avito_channel?
    avito_order_id.present? || source == "avito"
  end

  def insales_channel?
    insales_order_id.present? || source == "insales"
  end

  def moysklad_linked?
    moysklad_order_id.present?
  end

  def items_total
    order_items.sum { |i| i.line_sum }
  end
end
