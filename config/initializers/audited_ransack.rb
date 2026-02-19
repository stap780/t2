# Ransack support for Audited::Audit (used for product history filter)
Rails.application.config.to_prepare do
  Audited::Audit.class_eval do
    scope :audited_changes_has_key, ->(key) {
      return all if key.blank?
      where("audited_changes ? :key", key: key)
    }

    scope :audited_changes_key_old_present, ->(key) {
      return all if key.blank?
      where("jsonb_typeof(audited_changes->:key) = 'array' AND (audited_changes->:key)->0 IS NOT NULL", key: key)
    }

    scope :audited_changes_key_new_present, ->(key) {
      return all if key.blank?
      where("jsonb_typeof(audited_changes->:key) = 'array' AND (audited_changes->:key)->1 IS NOT NULL", key: key)
    }

    scope :created_at_dategteq, ->(date) {
      return all if date.blank?
      where("DATE(created_at) >= ?", date)
    }

    scope :created_at_datelteq, ->(date) {
      return all if date.blank?
      where("DATE(created_at) <= ?", date)
    }

    # Точный диапазон времени (для фильтра 18:18–19:27)
    scope :created_at_timegteq, ->(datetime) {
      return all if datetime.blank?
      where("created_at >= ?", datetime)
    }

    scope :created_at_timelteq, ->(datetime) {
      return all if datetime.blank?
      where("created_at <= ?", datetime)
    }

    def self.ransackable_attributes(auth_object = nil)
      %w[id user_id created_at associated_type associated_id auditable_type auditable_id action raw_audited_changes]
    end

    def self.ransackable_scopes(auth_object = nil)
      [:audited_changes_has_key, :audited_changes_key_old_present, :audited_changes_key_new_present,
       :created_at_dategteq, :created_at_datelteq, :created_at_timegteq, :created_at_timelteq]
    end
  end
end
