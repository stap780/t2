# frozen_string_literal: true

class Api::MoyskladsController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :verify_authenticity_token

  def order
    payload = request.body.read
    data = JSON.parse(payload.presence || "{}")
    events = data["events"] || []

    moysklad = Moysklad.first
    return head :ok unless moysklad

    events.each do |event|
      MoyskladApi::Orders::ProcessWebhookEvent.call(moysklad: moysklad, event: event)
    end

    head :ok
  rescue JSON::ParserError => e
    Rails.logger.error "[Api::MoyskladsController] Invalid JSON: #{e.message}"
    head :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "[Api::MoyskladsController] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    head :ok
  end
end
