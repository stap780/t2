# frozen_string_literal: true

class Api::InsalesController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :verify_authenticity_token

  before_action :set_insale

  # POST /api/insales/:id/order
  def order
    InsalesOrderImportJob.perform_later(@insale.id, order_payload)
    head :ok
  end

  private

  def set_insale
    @insale = Insale.find(params[:id])
  end

  def order_payload
    raw = request.request_parameters
    payload = raw["order"].is_a?(Hash) ? raw["order"] : raw
    payload = payload.to_unsafe_h if payload.respond_to?(:to_unsafe_h)
    payload.stringify_keys
  end
end
