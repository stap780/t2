# frozen_string_literal: true

class Avito < ApplicationRecord
  has_many :orders, dependent: :nullify

  validates :title, presence: true
  validates :api_id, presence: true, uniqueness: true
  validates :api_secret, presence: true, uniqueness: true

  def self.ransackable_attributes(_auth_object = nil)
    attribute_names
  end

  # Для ссылок из ProductIntegrationLinks (поиск по штрихкоду в ЛК)
  def product_list_url(q)
    "https://www.avito.ru/profile/pro/items?searchText=#{q}"
  end
end
