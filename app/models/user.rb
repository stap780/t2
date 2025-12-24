class User < ApplicationRecord
  has_secure_password
  
  # Use Rails 8 associations
  has_many :sessions, dependent: :destroy
  has_many :imports, dependent: :destroy
  has_many :exports, dependent: :destroy
  has_many :import_schedules, dependent: :destroy
  has_many :acts, foreign_key: 'driver_id', dependent: :nullify

  enum :role, { admin: "admin", user: "user", driver: "driver" }, default: "user"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  scope :drivers, -> { where(role: "driver") }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?

  def admin?
    role == "admin"
  end

  def self.ransackable_attributes(auth_object = nil)
    ["created_at", "email_address", "id", "id_value", "password_digest", "role", "updated_at"]
  end

  private

  def password_required?
    new_record? || password.present?
  end
end
