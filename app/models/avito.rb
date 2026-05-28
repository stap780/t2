# frozen_string_literal: true

class Avito < ApplicationRecord
  has_many :orders, dependent: :nullify
  has_many :avito_order_status_mappings, dependent: :destroy

  validates :title, presence: true
  validates :api_id, presence: true, uniqueness: true
  validates :api_secret, presence: true, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    attribute_names
  end

  def catalog_product_bindings_count
    Varbind.where(bindable: self, record_type: "Product").count
  end
end
