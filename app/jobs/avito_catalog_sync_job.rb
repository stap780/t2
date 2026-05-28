# frozen_string_literal: true

class AvitoCatalogSyncJob < ApplicationJob
  include Avito::EmailNotification

  queue_as :avito_catalog_sync

  def perform(avito_id = nil)
    scope = avito_id.present? ? Avito.where(id: avito_id) : Avito.all
    scope.find_each do |avito|
      stats = AvitoApi::Autoload::SyncCatalog.call(avito: avito)
      Rails.logger.info(
        "[AvitoCatalogSyncJob] avito=#{avito.id} linked=#{stats.linked} " \
        "existing=#{stats.existing} not_found=#{stats.not_found} " \
        "conflicts=#{stats.conflicts} skipped=#{stats.skipped} errors=#{stats.errors.size}"
      )
      create_catalog_sync_email_delivery(avito, stats)
    end
  end
end
