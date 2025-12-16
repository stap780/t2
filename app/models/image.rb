# Image
class Image < ApplicationRecord
  include Rails.application.routes.url_helpers
  require 'image_processing/vips'

  acts_as_list scope: :product, sequential_updates: false

  belongs_to :product
  has_one_attached :file do |attachable|
    attachable.variant :thumb, resize_to_limit: [400, 400]
    attachable.variant :default, saver: {strip: true}
    attachable.variant :thumb_webp, resize_to_limit: [400, 400], format: 'webp'
    attachable.variant :second, resize_to_fill: [1000, 1000], saver: { quality: 75, strip: true }
    # zap вариант генерируется через кастомный метод с водяным знаком
  end
  
  # Callback для предварительной генерации вариантов
  after_create_commit :schedule_variant_generation, if: -> { file.attached? }
  
  validates :position, uniqueness: { scope: :product }
  validate :is_image
  before_validation :set_position_if_nil, on: :create

  def self.ransackable_attributes(auth_object = nil)
    attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[file_attachment file_blob product]
  end

  def s3_url
    return unless file.attached?

    service = file.service
    if service.respond_to?(:bucket) && service.bucket.respond_to?(:name)
      "https://s3.timeweb.cloud/#{service.bucket.name}/#{file.blob.key}"
    else
      rails_blob_path(file, only_path: true)
    end
  end

  # URL для zap варианта с водяным знаком
  def zap_url
    return nil unless file.attached?
    
    # Проверяем наличие zap варианта в метаданных blob
    zap_key = file.blob.metadata['zap_variant_key']
    return nil unless zap_key
    
    # Получаем blob zap варианта
    zap_blob = ActiveStorage::Blob.find_by(key: zap_key)
    return nil unless zap_blob
    
    # Возвращаем URL
    service = zap_blob.service
    if service.respond_to?(:bucket) && service.bucket.respond_to?(:name)
      "https://s3.timeweb.cloud/#{service.bucket.name}/#{zap_blob.key}"
    else
      rails_blob_path(zap_blob, only_path: true)
    end
  end

  # URL для second варианта (квадратное изображение)
  def second_url
    return nil unless file.attached?
    
    begin
      second_variant = file.variant(:second)
      # Принудительно обрабатываем вариант если еще не обработан
      second_variant.processed
      second_variant.service.url(second_variant.key)
    rescue => e
      Rails.logger.warn "Image#second_url: Error generating second variant for Image ##{id}: #{e.message}"
      nil
    end
  end

  private

  def is_image
    return unless file.attached?

    unless file.blob.byte_size <= 10.megabyte
      errors.add(:file, 'is too big')
    end

    acceptable_types = ["image/jpeg", "image/png"]
    unless acceptable_types.include?(file.content_type)
      errors.add(:file, 'must be a JPEG or PNG')
    end
  end

  def set_position_if_nil
    return if position.present?
    last = Image.where(product_id: product.id).last
    self.position = last.present? ? last.position + 1 : 1
  end

  def schedule_variant_generation
    return unless file.attached?

     # если zap уже есть — ничего не делаем
    if file.blob.metadata.is_a?(Hash) && file.blob.metadata['zap_variant_key'].present?
      return
    end
    
    # Генерируем zap вариант в фоне (с водяным знаком)
    ImageZapVariantJob.perform_later(self)
  end
end
