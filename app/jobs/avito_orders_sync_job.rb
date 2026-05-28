# frozen_string_literal: true

class AvitoOrdersSyncJob < ApplicationJob
  queue_as :avito_orders_sync

  def perform(avito_id = nil)
    scope = avito_id.present? ? Avito.where(id: avito_id) : Avito.all
    scope.find_each do |avito|
      stats = AvitoApi::Orders::SyncAccount.call(avito: avito)
      Rails.logger.info(
        "[AvitoOrdersSyncJob] avito=#{avito.id} imported=#{stats.imported} " \
        "updated=#{stats.updated} skipped=#{stats.skipped} ms=#{stats.moysklad_created} " \
        "errors=#{stats.errors.size}"
      )
    end
  end
end
