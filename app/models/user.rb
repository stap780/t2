# frozen_string_literal: true

class User < ApplicationRecord
  has_secure_password

  has_many :sessions, dependent: :destroy
  has_many :imports, dependent: :destroy
  has_many :exports, dependent: :destroy
  has_many :import_schedules, dependent: :destroy
  has_many :acts, foreign_key: "driver_id", dependent: :nullify
  has_many :avito_catalog_link_digests, dependent: :nullify

  enum :role, { admin: "admin", user: "user", driver: "driver" }, default: "user"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  scope :drivers, -> { where(role: "driver") }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?
  validates :api_token, presence: true, uniqueness: true

  before_validation :assign_api_token, on: :create

  def admin?
    role == "admin"
  end

  def self.ransackable_attributes(auth_object = nil)
    ["api_token", "created_at", "email_address", "id", "id_value", "password_digest", "role", "updated_at"]
  end

  def full_name
    return email_address if name.blank? && surname.blank?

    "#{name} #{surname}".strip
  end

  private

  def password_required?
    new_record? || password.present?
  end

  def assign_api_token
    self.api_token ||= generate_api_token
  end

  def generate_api_token
    loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless self.class.exists?(api_token: token)
    end
  end
end
