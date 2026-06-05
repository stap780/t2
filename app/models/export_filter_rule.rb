class ExportFilterRule < ApplicationRecord
  belongs_to :export, inverse_of: :export_filter_rules
  belongs_to :property, optional: true
  belongs_to :characteristic, optional: true

  RULE_KEY_FEATURE = "feature"
  RULE_KEY_INSALE = "insale"
  RULE_KEY_MOYSKLAD = "moysklad"
  RULE_KEYS = [RULE_KEY_FEATURE, RULE_KEY_INSALE, RULE_KEY_MOYSKLAD].freeze
  INTEGRATION_RULE_KEYS = [RULE_KEY_INSALE, RULE_KEY_MOYSKLAD].freeze
  BINDING_VALUES = %w[yes no].freeze

  validates :rule_key, inclusion: { in: RULE_KEYS }
  validates :rule_condition, inclusion: { in: %w[eq not_eq] }
  validates :property_id, presence: true, if: :feature_rule?
  validates :characteristic_id, presence: true, if: :feature_rule?
  validates :rule_value, inclusion: { in: BINDING_VALUES }, if: :integration_rule?
  validate :characteristic_fits_property, if: :feature_rule?

  before_validation :clear_fields_for_rule_type
  before_validation :default_integration_rule_value

  def self.field_options
    integration = INTEGRATION_RULE_KEYS.map do |key|
      [I18n.t("exports.form.rule_#{key}"), key]
    end
    properties = Property.ordered.map { |property| [property.title, "property:#{property.id}"] }
    integration + properties
  end

  def field_selector_value
    return rule_key if integration_rule?
    return "property:#{property_id}" if property_id.present?

    nil
  end

  def assign_from_field_selector!(field)
    field = field.to_s
    if INTEGRATION_RULE_KEYS.include?(field)
      self.rule_key = field
      self.property_id = nil
      self.characteristic_id = nil
      self.rule_value ||= "yes"
    elsif (match = field.match(/\Aproperty:(\d+)\z/))
      self.rule_key = RULE_KEY_FEATURE
      self.property_id = match[1].to_i
      self.characteristic_id = nil
      self.rule_value = nil
    end
  end

  def integration_binding_present?
    (rule_condition == "eq") == (rule_value == "yes")
  end

  def feature_rule?
    rule_key == RULE_KEY_FEATURE
  end

  def integration_rule?
    INTEGRATION_RULE_KEYS.include?(rule_key)
  end

  def insale_rule?
    rule_key == RULE_KEY_INSALE
  end

  def moysklad_rule?
    rule_key == RULE_KEY_MOYSKLAD
  end

  private

  def default_integration_rule_value
    self.rule_value = "yes" if integration_rule? && rule_value.blank?
  end

  def clear_fields_for_rule_type
    if integration_rule?
      self.property_id = nil
      self.characteristic_id = nil
    elsif feature_rule?
      self.rule_value = nil
    end
  end

  def characteristic_fits_property
    return if characteristic_id.blank? || property_id.blank?
    return if Characteristic.exists?(id: characteristic_id, property_id: property_id)

    errors.add(:characteristic_id, :invalid)
  end
end
