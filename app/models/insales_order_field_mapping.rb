# frozen_string_literal: true

class InsalesOrderFieldMapping < ApplicationRecord
  include OrderFieldSourceKeys

  belongs_to :insale

  validates :source_key, presence: true, inclusion: { in: SOURCE_KEYS.keys }
  validates :source_key, uniqueness: { scope: :insale_id }
  validates :insales_field_id, presence: true, if: -> { insales_field_handle.blank? }
  validates :insales_field_handle, presence: true, if: -> { insales_field_id.blank? }
end
