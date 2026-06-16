# frozen_string_literal: true

class ClientIdentity
  AVITO_PLACEHOLDER_DOMAIN = "avito.local"

  def self.normalize_phone(phone)
    phone.to_s.gsub(/\D/, "")
  end

  def self.find_by_phone(phone)
    normalized = normalize_phone(phone)
    return nil if normalized.blank?

    ::Client.find_by(phone: normalized) ||
      ::Client.find_by(phone: phone.to_s.strip)
  end

  def self.avito_placeholder_email?(email)
    email.to_s.end_with?("@#{AVITO_PLACEHOLDER_DOMAIN}")
  end
end
