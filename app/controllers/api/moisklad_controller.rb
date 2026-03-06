# frozen_string_literal: true

class Api::MoiskladController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :verify_authenticity_token

  # POST /api/moisklad/order
  def order
    # Process incoming МойСклад order webhook
    # TODO: Implement order processing logic

    head :ok
  end
end
