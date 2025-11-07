class Insale < ApplicationRecord
  has_one_attached :swatch_file

  validates :api_link, presence: true
  validates :api_key, presence: true
  validates :api_password, presence: true

  # Initialize InSales API client
  def api_init
    InsalesApi::App.api_key = self.api_key
    InsalesApi::App.configure_api(self.api_link, self.api_password)
  end

  # Check API works
  # Returns [true, ""] or [false, messages]
  def api_work?
    return [false, ["No Insale configuration"]] unless self.persisted?

    self.api_init
    message = []
    begin
      account = InsalesApi::Account.find
    rescue SocketError
      message << "SocketError Check Key,Password,Domain"
    rescue ActiveResource::ResourceNotFound
      message << "not_found 404"
    rescue ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid
      message << "ActiveResource::ResourceConflict, ActiveResource::ResourceInvalid"
    rescue ActiveResource::UnauthorizedAccess
      message << "Failed.  Response code = 401.  Response message = Unauthorized"
    rescue ActiveResource::ForbiddenAccess
      message << "Failed.  Response code = 403.  Response message = Forbidden."
    rescue StandardError => e
      message << "StandardError #{e}"
    else
      account
    end
    message.size.positive? ? [false, message] : [true, ""]
  end

  # Add webhook for orders/create
  def self.add_order_webhook(rec: nil, address: nil)
    rec ||= Insale.first
    return [false, ["No Insale configuration"]] unless rec

    rec.api_init
    return [false, ["API not working"]] unless rec.api_work?[0]

    webh_list = InsalesApi::Webhook.all
    target_address = address || "#{Rails.application.config.public_host || 'http://localhost:3000'}/api/webhooks/insales/order"
    check_present = webh_list.any? { |w| w.topic == "orders/create" && w.address == target_address }

    if check_present
      message = "Webhook already exists. OK"
      return [true, message]
    end

    begin
      webhook = InsalesApi::Webhook.create(
        topic: "orders/create",
        address: target_address
      )
      [true, "Webhook created successfully"]
    rescue StandardError => e
      [false, ["Error creating webhook: #{e.message}"]]
    end
  end
end
