# frozen_string_literal: true

class AvitoCatalogLinksDigestJob < ApplicationJob
  include AvitoApi::EmailNotification

  queue_as :avito_catalog_sync

  def perform
    AvitoCatalogLinkDigest.where(digest_date: Date.yesterday).find_each do |digest|
      avito = digest.avito
      stats = digest.to_stats
      create_catalog_sync_email_delivery(avito, stats)
      digest.destroy!
      Rails.logger.info(
        "[AvitoCatalogLinksDigestJob] avito=#{avito.id} linked=#{stats.linked} " \
        "existing=#{stats.existing} not_found=#{stats.not_found} " \
        "conflicts=#{stats.conflicts} skipped=#{stats.skipped} errors=#{stats.errors.size}"
      )
    end
  end
end
