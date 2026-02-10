class Export < ApplicationRecord
  # Use Rails 8 associations
  belongs_to :user

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
  TEST_LIMIT = 1000

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
    variant_fields = %w[barcode sku price quantity cost_price]
    variant_fields_flat = variant_fields.map { |f| "variant_1_#{f}" }
    
    # Image fields
    image_fields = %w[images images_zap images_second images_thumb]
    
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
      variant_fields: %w[variants.first.barcode variants.first.sku variants.first.price variants.first.quantity variants.first.cost_price],
      feature_fields: ['features (for iteration)'],
      image_fields: %w[images images_zap images_second images_thumb]
    }
  end

  # Computes the next run time based on time-of-day in app timezone
  def next_run_at(from_time: Time.zone.now)
    return nil if time.blank?

    h, m = time.split(":").map(&:to_i)
    candidate = from_time.in_time_zone.change(hour: h, min: m, sec: 0)
    candidate += 1.day if candidate <= from_time
    candidate
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

  # Extract data from Product model with optimized queries
  def extract_data_from_products
    Rails.logger.info "🎯 Export ##{id}: Extracting data from Product model"

    # Оптимизированная загрузка с includes для избежания N+1 запросов
    products_scope = Product.active
      .includes(:variants, features: [:property, :characteristic], images: [:file_attachment, :file_blob])

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
    
    # Добавляем варианты - преобразуем в массив хешей со строковыми ключами
    hash['variants'] = product.variants.map do |variant|
      variant.attributes.with_indifferent_access
    end
    
    # Добавляем features как массив для итерации: for feature in product.features
    hash['features'] = product.features.map do |feature|
      {
        'property' => feature.property.title.to_s,
        'characteristic' => feature.characteristic.title.to_s
      }
    end
    
    # Добавляем изображения как массив URL
    # Используем выбранный вариант изображений или оригинал по умолчанию
    image_variant = image_variant_for_export || 'original'
    hash['images'] = product_images_urls(product, image_variant)
    
    # Также добавляем все варианты изображений для гибкости
    hash['images_zap'] = product_images_urls(product, 'zap')
    # hash['images_second'] = product_images_urls(product, 'second')
    
    hash
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
        image.zap_url
      when 'second'
        image.second_url
      else # 'original'
        image.s3_url
      end
    end.compact
  end


  private

  # Schedule next run if time is present and this change affected time
  def enqueue_on_create
    schedule! if time.present?
  end

  def handle_enqueue_on_update
    if saved_change_to_time?
      schedule! if time.present?
    end
  end

end
