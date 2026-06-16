# frozen_string_literal: true

module Api
  class AvitoCatalogLinksController < ApplicationController
    skip_before_action :require_authentication
    skip_before_action :verify_authenticity_token

    before_action :authenticate_api_user!

    # POST /api/avito/catalog_links
    def create
      items = parse_items
      if items.empty?
        return render json: { error: "items_required" }, status: :unprocessable_entity
      end

      stats = AvitoApi::CatalogLinks::Import.call(user: @api_user, items: items)
      render json: stats.to_h, status: :ok
    rescue JSON::ParserError => e
      Rails.logger.error "[Api::AvitoCatalogLinksController] Invalid JSON: #{e.message}"
      render json: { error: "invalid_json" }, status: :unprocessable_entity
    end

    private

    def authenticate_api_user!
      token = bearer_token
      @api_user = User.find_by(api_token: token) if token.present?
      head :unauthorized unless @api_user
    end

    def bearer_token
      request.authorization.to_s.sub(/\ABearer /i, "").strip.presence
    end

    def parse_items
      payload = request.request_parameters
      payload = payload.to_unsafe_h if payload.respond_to?(:to_unsafe_h)
      payload = payload.stringify_keys
      Array(payload["items"]).map do |item|
        item.respond_to?(:to_unsafe_h) ? item.to_unsafe_h.stringify_keys : item.stringify_keys
      end
    end
  end
end
