# frozen_string_literal: true

class ExportColumn < ApplicationRecord
  belongs_to :export, inverse_of: :export_columns

  validates :field_key, presence: true
  validates :field_key, inclusion: { in: ->(_) { Export.available_fields } }
  validates :field_key, uniqueness: { scope: :export_id }
  validates :label, length: { maximum: 255 }, allow_blank: true

  def header_title
    label.presence || Export.field_label(field_key)
  end
end
