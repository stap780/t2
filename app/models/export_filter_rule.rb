class ExportFilterRule < ApplicationRecord
  belongs_to :export, inverse_of: :export_filter_rules
  belongs_to :property, optional: true
  belongs_to :characteristic, optional: true

  RULE_KEY_FEATURE = "feature"

  validates :rule_key, inclusion: { in: [RULE_KEY_FEATURE] }
  validates :rule_condition, inclusion: { in: %w[eq not_eq] }
  validates :property_id, presence: true, if: :feature_rule?
  validates :characteristic_id, presence: true, if: :feature_rule?
  validate :characteristic_fits_property, if: :feature_rule?

  before_validation :clear_value_for_feature

  def feature_rule?
    rule_key == RULE_KEY_FEATURE
  end

  private

  def clear_value_for_feature
    self.rule_value = nil if feature_rule?
  end

  def characteristic_fits_property
    return if characteristic_id.blank? || property_id.blank?
    return if Characteristic.exists?(id: characteristic_id, property_id: property_id)

    errors.add(:characteristic_id, :invalid)
  end
end
