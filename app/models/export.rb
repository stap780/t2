class Export < ApplicationRecord
  # Use Rails 8 associations
  belongs_to :user
  has_many :export_filter_rules, -> { order(:position, :id) }, dependent: :destroy, inverse_of: :export
  has_many :export_columns, -> { order(:id) }, dependent: :destroy, inverse_of: :export
  accepts_nested_attributes_for :export_filter_rules,
    allow_destroy: true,
    reject_if: proc { |attrs|
      attrs = attrs.stringify_keys
      next false if attrs["_destroy"] == "1" || attrs["_destroy"] == true || attrs["_destroy"] == "true"

      rule_key = attrs["rule_key"].to_s
      if ExportFilterRule::INTEGRATION_RULE_KEYS.include?(rule_key)
        next attrs["id"].blank? && attrs["rule_value"].blank?
      end
      next false unless rule_key == ExportFilterRule::RULE_KEY_FEATURE

      attrs["id"].blank? && attrs["property_id"].blank? && attrs["characteristic_id"].blank?
    }
  accepts_nested_attributes_for :export_columns,
    allow_destroy: true,
    reject_if: proc { |attrs|
      attrs = attrs.stringify_keys
      next false if attrs["_destroy"] == "1" || attrs["_destroy"] == true || attrs["_destroy"] == "true"

      attrs["id"].blank? && attrs["field_key"].blank?
    }

  # Active Storage attachment for the exported file
  has_one_attached :export_file

  after_create_commit { broadcast_prepend_to "exports" }
  after_update_commit { broadcast_replace_to "exports" }
  after_destroy_commit { broadcast_remove_to "exports" }

  # Use Rails 8 query methods and optimizations
  scope :recent, -> { order(created_at: :desc) }
  scope :completed, -> { where(status: "completed") }
  scope :pending, -> { where(status: "pending") }
  scope :processing, -> { where(status: "processing") }
  scope :failed, -> { where(status: "failed") }
  scope :with_errors, -> { where(status: "failed").where.not(error_message: [nil, ""]) }
  scope :test_exports, -> { where(test: true) }
  scope :production_exports, -> { where(test: false) }

  # Leverage Rails 8 security features
  validates :name, presence: true
  validates :format, presence: true, inclusion: { in: %w[csv xlsx xml] }
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }
  validates :user, presence: true
  validates :interval_hours, inclusion: { in: [1, 2, 3, 4, 5, 6], allow_nil: true }

  with_options if: -> { format == "xml" } do
    validates :layout_template, presence: true
    validates :item_template, presence: true
  end

  validates :export_columns,
    length: { minimum: 1, message: ->(*) { I18n.t("exports.errors.columns_required") } },
    if: :requires_export_columns?

  # Serialize file_headers as array to store selected field headers
  serialize :file_headers, coder: JSON

  # Format constants inspired by Dizauto
  FORMATS = [
    ['CSV', 'csv'],
    ['Excel (XLSX)', 'xlsx'],
    ['XML', 'xml']
  ].freeze

  STATUS = %w[pending processing completed failed].freeze

  # Test mode limit
  TEST_LIMIT = 5000

  # Callbacks
  before_validation :set_default_name, on: :create
  before_validation :set_default_test_mode, on: :create
  after_commit :enqueue_on_create, on: :create
  # Use after_update so saved_change_to_time? is available
  after_update :handle_enqueue_on_update
  before_destroy :cancel_pending_job

  def completed?
    status == "completed"
  end

  def pending?
    status == "pending"
  end

  def processing?
    status == "processing"
  end

  def failed?
    status == "failed"
  end

  def has_error?
    failed? && error_message.present?
  end

  def error_summary
    return nil unless has_error?

    # Truncate long error messages for display
    error_message.length > 100 ? "#{error_message[0..97]}..." : error_message
  end

  def status_color
    case status
    when "completed"
      "bg-green-100 text-green-800"
    when "processing"
      "bg-blue-100 text-blue-800"
    when "failed"
      "bg-red-100 text-red-800"
    else
      "bg-yellow-100 text-yellow-800"
    end
  end

  def test_mode?
    test == true
  end

  def production_mode?
    !test_mode?
  end

  def record_limit
    test_mode? ? TEST_LIMIT : nil
  end

  # Extract data for template rendering (now from Product model)
  def data
    @data ||= extract_data_from_products
  end

  # Convert to Liquid drop for template rendering (like Dizauto)
  def to_liquid
    @drop ||= Drop::Export.new(self)
  end

  def has_data_source?
    Product.any?
  end

  # Get available fields for export (used in forms and export service)
  def self.available_fields
    # Base Product fields
    product_fields = %w[id status tip title description created_at updated_at]
    
    # Variant fields (will be flattened as variant_1_barcode, variant_1_sku, etc.)
    variant_fields = %w[barcode sku price sprice quantity cost_price]
    variant_fields_flat = variant_fields.map { |f| "variant_1_#{f}" }
    
    # Image fields
    image_fields = %w[images] #images_zap images_second images_thumb
    
    # Feature fields - используем реальные названия свойств из базы данных
    # Получаем все уникальные названия свойств, которые используются в продуктах
    property_titles = Property.joins(:features)
                              .where(features: { featureable_type: 'Product' })
                              .distinct
                              .pluck(:title)
    
    # Если свойств нет, используем пустой массив
    feature_fields_flat = property_titles.map { |title| "feature_#{title}" }
    
    # Combine all fields
    product_fields + variant_fields_flat + image_fields + feature_fields_flat
  end

  def requires_export_columns?
    persisted? && %w[csv xlsx].include?(format)
  end

  def flat_export_format?
    %w[csv xlsx].include?(format)
  end

  # Status updates during ExportJob must not fail when column validation applies to the form only.
  def update_export_run_status!(status, exported_at: nil, error_message: nil)
    attrs = { status: status, updated_at: Time.current }
    attrs[:exported_at] = exported_at if exported_at
    attrs[:error_message] = error_message unless error_message.nil?
    update_columns(attrs)
  end

  # Get translated field name for display
  def self.field_label(field_name)
    if field_name.include?("feature_")
      value = field_name.split("_").last
      "Параметр: #{value}"
    else
      I18n.t("exports.fields.#{field_name}")
    end
  end

  # Get available fields for Liquid template (for XML exports)
  def self.available_product_fields_for_template
    {
      product_fields: %w[id status tip title description created_at updated_at],
      variant_fields: %w[variants.first.barcode variants.first.sku variants.first.price variants.first.sprice variants.first.quantity variants.first.cost_price],
      feature_fields: ['features (for iteration)'],
      binding_fields: ['bindings (for iteration)'],
      image_fields: %w[images images_with_ext] #images_zap images_second images_thumb
    }
  end

  # Computes the next run time:
  # - interval_hours + time → every N hours starting from time (time as anchor)
  # - interval_hours only → from_time + interval_hours
  # - time only → daily at that time
  # - both blank → nil (manual only)
  def next_run_at(from_time: Time.zone.now)
    if interval_hours.present? && interval_hours.positive?
      if time.present?
        h, m = time.split(":").map(&:to_i)
        anchor = from_time.in_time_zone.change(hour: h, min: m, sec: 0)
        anchor -= 1.day if anchor > from_time
        elapsed = from_time - anchor
        periods = (elapsed / interval_hours.hours).ceil
        anchor + (periods * interval_hours).hours
      else
        from_time + interval_hours.hours
      end
    elsif time.present?
      h, m = time.split(":").map(&:to_i)
      candidate = from_time.in_time_zone.change(hour: h, min: m, sec: 0)
      candidate += 1.day if candidate <= from_time
      candidate
    else
      nil
    end
  end

  def periodic_scheduled?
    time.present? || interval_hours.present?
  end

  # Schedule the export job at the next occurrence and track scheduled_for.
  # Cancel any existing scheduled job first (we store active_job_id for this).
  def schedule!
    cancel_pending_job

    ts = next_run_at
    return unless ts

    update_columns(scheduled_for: ts)
    job = ExportJob.set(wait_until: ts).perform_later(self, ts)
    update_columns(active_job_id: job.job_id)
  end

  # Call from job after finishing to create a daily schedule
  def schedule_next_day!
    cancel_pending_job
    
    ts = next_run_at(from_time: Time.zone.now + 1.minute)
    return unless ts
    update_columns(scheduled_for: ts)
    job = ExportJob.set(wait_until: ts).perform_later(self, ts)
    update_columns(active_job_id: job.job_id)
  end

  # Remove ALL pending scheduled jobs for this export, if present.
  # 1) По active_job_id (старый механизм, для совместимости)
  # 2) По GlobalID экспорта, чтобы удалить все задачи ExportJob для данного Export,
  #    независимо от того, какой active_job_id сейчас записан.
  # Порядок: сначала ScheduledExecution (чтобы исчезли из Scheduled jobs UI), потом Job.
  def cancel_pending_job
    # Ничего не делаем, если SolidQueue не подключён
    return unless defined?(SolidQueue::ScheduledExecution) && defined?(SolidQueue::Job)

    # 1. Удаляем по active_job_id (если он есть)
    if active_job_id.present?
      SolidQueue::ScheduledExecution.joins(:job)
        .where(solid_queue_jobs: { active_job_id: active_job_id })
        .delete_all

      SolidQueue::Job.where(active_job_id: active_job_id, finished_at: nil).delete_all
    end

    # 2. Дополнительно удаляем все задачи ExportJob для этого Export по GlobalID,
    #    чтобы в расписании всегда была максимум одна задача на экспорт.
    begin
      gid = to_global_id.to_s
    rescue StandardError
      gid = nil
    end

    if gid.present?
      scheduled_scope = SolidQueue::ScheduledExecution.joins(:job)
        .where(solid_queue_jobs: { queue_name: "export", class_name: "ExportJob" })
        .where("solid_queue_jobs.arguments LIKE ?", "%#{gid}%")

      job_scope = SolidQueue::Job.where(queue_name: "export", class_name: "ExportJob", finished_at: nil)
        .where("arguments LIKE ?", "%#{gid}%")

      scheduled_scope.delete_all
      job_scope.delete_all
    end

    # После очистки сбрасываем active_job_id — новую задачу назначит schedule!/schedule_next_day!
    update_columns(active_job_id: nil)
  rescue => e
    Rails.logger.warn("Export##{id}: failed to cancel pending job #{active_job_id}: #{e.message}")
  end

  def set_default_name
    if name.blank?
      self.name = "Export #{Time.current.strftime('%Y%m%d_%H%M%S')}"
    end
  end

  def set_default_test_mode
    # Default to test mode for new exports to prevent accidental large exports
    self.test = true if test.nil?
  end

  # NOTE: legacy XML template support
  # Поле `template` использовалось для полного Liquid-шаблона XML.
  # Новая схема: layout_template (каркас с {{ items_xml }}) + item_template (один товар).
  # Существующие экспорты с заполненным template нужно вручную перенести на новую схему.

  # Extract data from Product model with optimized queries
  def extract_data_from_products
    Rails.logger.info "🎯 Export ##{id}: Extracting data from Product model"

    base_scope = Product.active.yes_quantity.yes_price.with_images
    base_scope = apply_integration_filters(base_scope)
    base_scope = apply_property_filters(base_scope, property_filters_for_export)

    # Оптимизированная загрузка с includes для избежания N+1 запросов
    products_scope = base_scope
      .includes(
        :bindings,
        variants: :bindings,
        features: [:property, :characteristic],
        images: [:file_attachment, :file_blob]
      )

    # Применение тестового режима
    if test_mode?
      products_scope = products_scope.limit(TEST_LIMIT)
      Rails.logger.info "🎯 Export ##{id}: TEST MODE - Limiting to #{TEST_LIMIT} products"
    end

    # Преобразование в массив хешей
    data_array = products_scope.find_each(batch_size: 100).map do |product|
      product_to_hash(product)
    end

    Rails.logger.info "🎯 Export ##{id}: Extracted #{data_array.length} products"
    data_array
  rescue => e
    Rails.logger.error "🎯 Export ##{id}: Error extracting data from products: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    []
  end

  # Convert Product to hash for export
  def product_to_hash(product)
    # Используем with_indifferent_access для работы со строковыми и символическими ключами
    hash = product.attributes.with_indifferent_access.dup
    
    # Добавляем описание как plain text
    hash['description'] = product.file_description
    
    hash['bindings'] = bindings_to_array(product.bindings)

    # Добавляем варианты - преобразуем в массив хешей со строковыми ключами
    hash['variants'] = product.variants.map do |variant|
      v = variant.attributes.with_indifferent_access
      v['bindings'] = bindings_to_array(variant.bindings)
      v
    end
    
    # Добавляем features:
    # 1) как массив для итерации в шаблонах (XML, Liquid)
    hash['features'] = product.features.map do |feature|
      {
        'property' => feature.property.title.to_s,
        'characteristic' => feature.characteristic.title.to_s
      }
    end
    # 2) как хеш "Название свойства" => "Значение" для плоских экспортов (CSV/XLSX)
    hash['features_hash'] = product.features_to_h
    
    # Добавляем изображения только когда они нужны для экспорта
    if needs_images_for_export?
      hash['images'] = product_images_urls(product, 'original')
      hash['images_with_ext'] = product_images_urls_with_ext(product, 'original')
    end

    hash
  end

  def needs_images_for_export?
    return true if format == "xml"

    export_columns.any? { |c| c.field_key == "images" }
  end

  # Get image variant for export (can be extended with image_variant field)
  def image_variant_for_export
    # Можно добавить поле image_variant в модель Export для выбора варианта
    # Пока используем оригинал по умолчанию
    nil # или self.image_variant если поле добавлено
  end

  # Get product images URLs for specific variant
  def product_images_urls(product, variant = 'original')
    return [] unless product.images.present?
    
    product.images.map do |image|
      case variant
      when 'zap'
        # image.zap_url
      when 'second'
        # image.second_url
      else # 'original'
        image.s3_url
      end
    end.compact
  end

  # URLs с расширением в пути (через Rails blob URL — для YML и сервисов, требующих .jpg/.png)
  def product_images_urls_with_ext(product, variant = 'original')
    return [] unless product.images.present?

    product.images.filter_map(&:rails_blob_url_with_filename)
  end

  private

  def bindings_to_array(bindings)
    bindings.map do |varbind|
      {
        'bindable_type' => varbind.bindable_type.to_s,
        'bindable_id' => varbind.bindable_id,
        'value' => varbind.value.to_s
      }
    end
  end

  def integration_filters_for_export
    export_filter_rules.where(rule_key: ExportFilterRule::INTEGRATION_RULE_KEYS)
  end

  def apply_integration_filters(scope)
    integration_filters_for_export.each do |rule|
      with_binding = rule.integration_binding_present?

      case rule.rule_key
      when ExportFilterRule::RULE_KEY_INSALE
        scope = with_binding ? scope.with_insale : scope.without_insale
      when ExportFilterRule::RULE_KEY_MOYSKLAD
        scope = with_binding ? scope.with_moysklad : scope.without_moysklad
      end
    end

    scope.distinct
  end

  def property_filters_for_export
    export_filter_rules
      .where(rule_key: ExportFilterRule::RULE_KEY_FEATURE)
      .where.not(property_id: nil)
      .where.not(characteristic_id: nil)
      .map do |r|
        {
          "property_id" => r.property_id.to_s,
          "predicate" => r.rule_condition,
          "value" => r.characteristic_id.to_s
        }
      end
  end

  def apply_property_filters(scope, filters)
    return scope if filters.blank?

    filters.each do |row|
      pid = row["property_id"].to_i
      pred = row["predicate"]
      val = row["value"]
      next if pid.zero?

      case pred
      when "eq"
        cid = val.to_i
        next if cid.zero?

        ids = feature_product_ids_for_eq(pid, cid)
        scope = scope.where(id: ids)
      when "not_eq"
        cid = val.to_i
        next if cid.zero?

        ids = feature_product_ids_for_eq(pid, cid)
        scope = scope.where.not(id: ids)
      end
    end

    scope.distinct
  end

  def feature_product_ids_for_eq(property_id, characteristic_id)
    Feature.where(
      featureable_type: "Product",
      property_id: property_id,
      characteristic_id: characteristic_id
    ).select(:featureable_id)
  end

  def enqueue_on_create
    schedule! if periodic_scheduled?
  end

  def handle_enqueue_on_update
    if periodic_scheduled?
      schedule!
    else
      cancel_pending_job
    end
  end

end
