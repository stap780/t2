class ProductPriceUpdateJob < ApplicationJob
  queue_as :default

  def perform(product_ids, field_type, move, shift, points, round)
    products = Product.where(id: product_ids)
    
    products.find_each do |product|
      product.variants.each do |variant|
        current_price = variant.price || 0
        
        new_price = case field_type
        when 'price'
          calculate_new_price(current_price, move, shift, points, round)
        when 'cost_price'
          # Аналогично для себестоимости, если нужно
          current_price
        else
          current_price
        end
        
        variant.update(price: new_price)
      end
    end
  end

  private

  def calculate_new_price(current_price, move, shift, points, round)
    new_price = current_price
    
    # move: 'percent' или 'fixed'
    # shift: значение изменения
    # points: количество знаков после запятой
    # round: округление
    
    if move == 'percent'
      new_price = current_price * (1 + shift.to_f / 100)
    elsif move == 'fixed'
      new_price = current_price + shift.to_f
    end
    
    # Округление
    if round.present?
      new_price = new_price.round(round.to_i)
    else
      new_price = new_price.round(points.to_i)
    end
    
    new_price
  end
end

