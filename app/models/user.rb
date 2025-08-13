class User < ApplicationRecord
  has_secure_password
  
  # Use Rails 8 associations
  has_many :sessions, dependent: :destroy
  has_many :imports, dependent: :destroy
  has_many :exports, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true
end
