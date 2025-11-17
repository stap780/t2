class ProductPriceUpdateJob < ApplicationJob
  queue_as :default

  def perform(product_ids, field_type, move, shift, points, round, current_user_id = nil)
    products = Product.where(id: product_ids)

    success, message = Product::PriceUpdate.new(products, {
      field_type: field_type,
      move: move,
      shift: shift,
      points: points,
      round: round
    }).call

    if success
      Rails.logger.info "ProductPriceUpdateJob: Successfully updated prices for #{product_ids.count} products"
      # TODO: Добавить уведомления пользователю через Turbo Streams или Notifications
    else
      Rails.logger.error "ProductPriceUpdateJob: Failed to update prices: #{message.inspect}"
      # TODO: Добавить уведомления об ошибке
    end
  end
end

