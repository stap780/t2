# frozen_string_literal: true

class OrderStatus < ApplicationRecord
  include NormalizeDataWhiteSpace
  include ActionView::RecordIdentifier

  acts_as_list

  after_create_commit { broadcast_prepend_to "order_statuses" }
  after_update_commit { broadcast_replace_to "order_statuses" }
  after_destroy_commit { broadcast_remove_to "order_statuses" }

  has_many :orders, dependent: :restrict_with_error
  has_many :moysklad_order_status_mappings, dependent: :destroy
  has_one :avito_order_status_mapping, dependent: :destroy
  has_many :insales_order_status_mappings, dependent: :destroy

  before_validation :generate_code_from_title, if: -> { code.blank? && title.present? }

  validates :code, presence: true, uniqueness: true
  validates :code, format: { with: /\A[a-z0-9_]+\z/, message: "только латиница, цифры и подчёркивания" },
                    allow_blank: true
  validates :title, presence: true

  def self.ransackable_attributes(_auth_object = nil)
    attribute_names
  end

  private

  def generate_code_from_title
    transliterated = transliterate(title)
    self.code = transliterated.downcase
      .gsub(/[^a-z0-9\s]/, "")
      .gsub(/\s+/, "_")
      .gsub(/_+/, "_")
      .gsub(/^_|_$/, "")

    self.code = "status_#{SecureRandom.hex(4)}" if code.blank? || code.length < 2

    ensure_unique_code
  end

  def ensure_unique_code
    base_code = code
    counter = 1
    while self.class.where.not(id: id || 0).exists?(code: code)
      self.code = "#{base_code}_#{counter}"
      counter += 1
    end
  end

  def transliterate(text)
    text.to_s
      .gsub(/[аА]/, "a").gsub(/[бБ]/, "b").gsub(/[вВ]/, "v").gsub(/[гГ]/, "g")
      .gsub(/[дД]/, "d").gsub(/[еЕёЁ]/, "e").gsub(/[жЖ]/, "zh").gsub(/[зЗ]/, "z")
      .gsub(/[иИ]/, "i").gsub(/[йЙ]/, "y").gsub(/[кК]/, "k").gsub(/[лЛ]/, "l")
      .gsub(/[мМ]/, "m").gsub(/[нН]/, "n").gsub(/[оО]/, "o").gsub(/[пП]/, "p")
      .gsub(/[рР]/, "r").gsub(/[сС]/, "s").gsub(/[тТ]/, "t").gsub(/[уУ]/, "u")
      .gsub(/[фФ]/, "f").gsub(/[хХ]/, "h").gsub(/[цЦ]/, "ts").gsub(/[чЧ]/, "ch")
      .gsub(/[шШ]/, "sh").gsub(/[щЩ]/, "sch").gsub(/[ъЪьЬ]/, "").gsub(/[ыЫ]/, "y")
      .gsub(/[эЭ]/, "e").gsub(/[юЮ]/, "yu").gsub(/[яЯ]/, "ya")
  end
end
