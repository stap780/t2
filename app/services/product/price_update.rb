class Product::PriceUpdate
  def initialize(products, options = {})
    @products = products
    @field_type = options[:field_type]
    @move = options[:move]
    @shift = options[:shift]
    @points = options[:points]
    @round = options[:round]
    @updated_count = 0
    @errors = []
  end

  def call
    update
    {
      success: @errors.empty?,
      updated_count: @updated_count,
      error_count: @errors.size,
      errors: @errors,
      total: @products.count
    }
  end

  private

  def update
    @products.find_each do |product|
      product.variants.each do |variant|
        sale_price = variant.price.present? ? variant.price : nil
        next if sale_price.nil?

        new_price = calculate_new_price(sale_price, @move, @shift, @points, @round)

        next if new_price.blank?

        if variant.update(price: new_price)
          @updated_count += 1
        else
          @errors << {
            variant_id: variant.id,
            product_id: product.id,
            sku: variant.sku,
            barcode: variant.barcode,
            messages: variant.errors.full_messages
          }
        end
      end
      product.update(title: product.title)
    end
  end

  def calculate_new_price(sale_price, move, shift, points, round)
    # move: 'plus' или 'minus'
    # shift: значение изменения
    # points: 'percents' или 'fixed'
    # round: '-2', '-1', '0' (для округления)

    if points == 'fixed'
      # Фиксированное изменение
      if move == 'plus'
        new_price = sale_price + shift.to_f
      else # 'minus'
        new_price = sale_price - shift.to_f
      end
    else
      # Процентное изменение
      if move == 'plus'
        new_price = sale_price + shift.to_f * 0.01 * sale_price
      else # 'minus'
        new_price = sale_price - shift.to_f * 0.01 * sale_price
      end
    end

    # Округление (round: '-2' до сотен, '-1' до десятков, '0' без округления)
    new_price = new_price.round(round.to_i)

    new_price
  end

end

