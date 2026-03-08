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
      next unless event["meta"]&.dig("type") == "customerorder"

      href = event.dig("meta", "href")
      next if href.blank?

      order_json = MoyskladApi::Order.fetch(moysklad, href)
      next unless order_json

      process_order_positions(order_json, moysklad)
    end

    head :ok
  rescue JSON::ParserError => e
    Rails.logger.error "[Api::MoyskladsController] Invalid JSON: #{e.message}"
    head :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "[Api::MoyskladsController] Error: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    head :ok
  end

  private

  def process_order_positions(order_json, moysklad)
    rows = order_json.dig("positions", "rows") || []
    rows.each do |row|
      href = row.dig("assortment", "meta", "href")
      next if href.blank?

      product_id = href.to_s.split("/").last
      next if product_id.blank?

      varbind = Varbind.find_by(bindable: moysklad, value: product_id)
      next unless varbind

      variant = varbind.record
      next unless variant.is_a?(Variant)

      reserve = (row["reserve"] || 0).to_i
      next if reserve <= 0

      new_quantity = [variant.quantity - reserve, 0].max
      variant.update!(quantity: new_quantity)
    rescue StandardError => e
      Rails.logger.error "[Api::MoyskladsController] Error processing position: #{e.message}"
    end
  end
end
