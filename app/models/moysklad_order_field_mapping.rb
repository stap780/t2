# frozen_string_literal: true

class MoyskladOrderFieldMapping < ApplicationRecord
  include OrderFieldSourceKeys

  belongs_to :moysklad

  validates :source_key, presence: true, inclusion: { in: SOURCE_KEYS.keys }
  validates :ms_attribute_href, presence: true
  validates :source_key, uniqueness: { scope: :moysklad_id }
end
