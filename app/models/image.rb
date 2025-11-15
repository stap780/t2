# Image
class Image < ApplicationRecord
  include Rails.application.routes.url_helpers
  # require 'image_processing/vips'

  acts_as_list scope: :product, sequential_updates: false

  belongs_to :product
  has_one_attached :file do |attachable|
    attachable.variant :thumb, resize_to_limit: [200, 200]
    attachable.variant :default, saver: {strip: true}
    attachable.variant :thumb_webp, resize_to_limit: [200, 200], format: 'webp'
  end
  
  validates :position, uniqueness: { scope: :product }
  validate :validate_image
  before_validation :set_position_if_nil, on: :create

  def self.ransackable_attributes(auth_object = nil)
    Image.attribute_names
  end

  def self.ransackable_associations(auth_object = nil)
    %w[file_attachment file_blob product]
  end

  def s3_url
    "https://s3.timeweb.cloud/#{self.file.service.bucket.name}/#{self.file.blob.key}"
  end

  private

  def validate_image
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
end
