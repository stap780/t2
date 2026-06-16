class Moysklad < ApplicationRecord
  AD_SOURCE_ATTRIBUTE_NAME = "Источник рекламы"

  has_many :moysklad_order_field_mappings, dependent: :destroy

  validates :api_key, presence: true
  validates :api_password, presence: true
  validates :title, presence: true

  before_validation :ensure_title

  # Check API works
  # Returns [true, ""] or [false, messages]
  def api_work?
    return [false, ["No Moysklad configuration"]] unless persisted?

    message = []
    begin
      token = MoyskladApi::Webhook.fetch_access_token(self)
      [token.present?, ""]
    rescue SocketError
      message << "SocketError Check Key,Password"
    rescue StandardError => e
      message << "StandardError #{e}"
    end
    message.size.positive? ? [false, message] : [true, ""]
  end

  private

  def ensure_title
    self.title = "МойСклад" if title.blank?
  end
end
