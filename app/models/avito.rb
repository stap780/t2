# frozen_string_literal: true

class Avito < ApplicationRecord
  has_many :orders, dependent: :nullify
  has_many :avito_order_status_mappings, dependent: :destroy
  has_many :avito_catalog_link_digests, dependent: :destroy

  validates :title, presence: true
  validates :api_id, presence: true, uniqueness: true
  validates :api_secret, presence: true, uniqueness: true
    validates :profileid, presence: true, uniqueness: true

    before_validation :assign_test_profileid, on: :create, if: -> { Rails.env.test? && profileid.blank? }

  def self.ransackable_attributes(_auth_object = nil)
    attribute_names
  end

  def catalog_product_bindings_count
    Varbind.where(bindable: self, record_type: "Product").count
  end

  private

  def assign_test_profileid
    loop do
      candidate = 70_000_000 + SecureRandom.random_number(29_999_999)
      unless self.class.exists?(profileid: candidate)
        self.profileid = candidate
        break
      end
    end
  end
end
