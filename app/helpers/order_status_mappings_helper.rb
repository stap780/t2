# frozen_string_literal: true

module OrderStatusMappingsHelper
  def order_status_options_for_select(selected = nil)
    options_from_collection_for_select(
      OrderStatus.order(:position),
      :id,
      :title,
      selected
    )
  end

  def insale_options_for_select(selected = nil, include_blank: true)
    collection = Insale.order(:id).map { |i| ["InSales ##{i.id} (#{i.api_link})", i.id] }
    options_for_select(collection, selected)
  end
end
