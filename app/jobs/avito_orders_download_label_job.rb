# frozen_string_literal: true

class AvitoOrdersDownloadLabelJob < ApplicationJob
  queue_as :avito_orders_download_label

  def perform(order_id, payload = nil)
    order = Order.find_by(id: order_id)
    return unless order

    result = AvitoApi::Orders::DownloadLabel.call(order: order, payload: payload)
    return if result.success || result.skipped

    Rails.logger.warn(
      "[AvitoOrdersDownloadLabelJob] order=#{order_id} error=#{result.error}"
    )
  end
end
