class Api::Webhooks::InsalesController < ApplicationController
  skip_before_action :require_authentication
  skip_before_action :verify_authenticity_token

  # POST /api/webhooks/insales/order
  def order
    # Process incoming InSales order webhook
    # TODO: Implement order processing logic
    
    head :ok
  end
end

