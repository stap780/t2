class Insale < ApplicationRecord
  has_many :orders, dependent: :nullify
  has_many :insales_order_status_mappings, dependent: :destroy
  has_many :insales_order_field_mappings, dependent: :destroy
  has_one_attached :swatch_file

  validates :api_link, presence: true
  validates :api_key, presence: true
  validates :api_password, presence: true
  validates :title, presence: true

  before_validation :ensure_title

  def api_init
    InsalesApi::App.api_key = api_key
    InsalesApi::App.configure_api(api_link, api_password)
  end

  # Returns [true, ""] or [false, messages]
  def api_work?
    return [false, ["No Insale configuration"]] unless persisted?

    api_init
    message = []
    begin
      InsalesApi::Account.find
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
    end
    message.size.positive? ? [false, message] : [true, ""]
  end

  def add_order_webhook(address: nil)
    register_webhook(topic: "orders/create", address: address)
  end

  def add_order_update_webhook(address: nil)
    register_webhook(topic: "orders/update", address: address)
  end

  def self.add_order_webhook(rec: nil, address: nil)
    rec ||= Insale.first
    return [false, ["No Insale configuration"]] unless rec

    rec.add_order_webhook(address: address)
  end

  private

  def register_webhook(topic:, address: nil)
    return [false, ["API not working"]] unless api_work?[0]

    api_init
    target_address = address || webhook_order_url
    existing = InsalesApi::Webhook.all.any? { |w| w.topic == topic && w.address == target_address }
    return [true, "Webhook already exists. OK"] if existing

    data = {
      address: target_address,
      topic: topic,
      format_type: "json"
    }

    message = []
    webhook = InsalesApi::Webhook.new(webhook: data)
    begin
      webhook.save
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
      message << "Error creating webhook: #{e.message}"
    end

    message.size.positive? ? [false, message] : [true, "Webhook created successfully"]
  end

  def webhook_order_url
    opts = Rails.application.config.action_mailer.default_url_options || {}
    host = ENV.fetch("APP_PUBLIC_HOST", opts[:host] || "localhost")
    protocol = ENV.fetch("APP_PUBLIC_PROTOCOL", opts[:protocol] || "http")
    port = opts[:port]
    url_opts = { host: host, protocol: protocol }
    url_opts[:port] = port if port.present? && !host.include?(":")

    Rails.application.routes.url_helpers.api_insale_order_url(id, **url_opts)
  end

  private

  def ensure_title
    self.title = api_link if title.blank? && api_link.present?
  end
end
