class Moysklad < ApplicationRecord
  validates :api_key, presence: true
  validates :api_password, presence: true

  # Check API works
  # Returns [true, ""] or [false, messages]
  def api_work?
    return [false, ["No Moysklad configuration"]] unless self.persisted?

    message = []
    begin
      # TODO: Implement Moysklad API check
      # For now, just return success
      [true, ""]
    rescue SocketError
      message << "SocketError Check Key,Password"
    rescue StandardError => e
      message << "StandardError #{e}"
    end
    message.size.positive? ? [false, message] : [true, ""]
  end
end

