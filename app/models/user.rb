class User < ApplicationRecord
  has_secure_password
  
  # Use Rails 8 associations
  has_many :sessions, dependent: :destroy
  has_many :imports, dependent: :destroy
  has_many :exports, dependent: :destroy
  has_many :import_schedules, dependent: :destroy

  enum :role, { admin: "admin", user: "user" }, default: "user"

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, presence: true, length: { minimum: 6 }, if: :password_required?
  validates :password_confirmation, presence: true, if: :password_required?

  def admin?
    role == "admin"
  end

  private

  def password_required?
    new_record? || password.present?
  end
end
