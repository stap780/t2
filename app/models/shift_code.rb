class ShiftCode < ApplicationRecord
  acts_as_list

  has_many :schedule_days, dependent: :restrict_with_error

  before_validation :generate_code_from_label, if: -> { code.blank? && label.present? }

  validates :code, presence: true, uniqueness: true
  validates :label, presence: true
  validates :code, format: { with: /\A[a-zA-Z0-9_]+\z/ }

  scope :ordered, -> { order(:position, :code) }

  private

  def generate_code_from_label
    base = label.to_s.parameterize(separator: "_")
    if base.blank? || base.length < 2
      base = "code_#{SecureRandom.hex(4)}"
    end
    self.code = base
    ensure_unique_code
  end

  def ensure_unique_code
    base_name = code
    counter = 1
    while ShiftCode.where.not(id: id || 0).exists?(code: code)
      self.code = "#{base_name}_#{counter}"
      counter += 1
    end
  end
end
