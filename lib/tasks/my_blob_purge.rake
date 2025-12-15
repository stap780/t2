namespace :my_blob do
  desc "Safely purge unattached ActiveStorage blobs, excluding zap variants used by images"
  task purge: :environment do
    puts "📦 Blob purge: collecting used zap_variant_key values..."

    # 1. Собираем все используемые zap-ключи из metadata исходных блобов
    used_zap_keys = ActiveStorage::Blob
      .where.not(metadata: nil)
      .pluck(:metadata)
      .map { |m| m["zap_variant_key"] }
      .compact
      .uniq

    puts "📦 Blob purge: найдено используемых zap-ключей: #{used_zap_keys.size}"

    # 2. Берём только действительно unattached-блобы, у которых key НЕ в used_zap_keys
    blobs_to_purge = ActiveStorage::Blob.unattached.where.not(key: used_zap_keys)

    total = blobs_to_purge.count
    puts "📦 Blob purge: будет удалено unattached без zap-ссылок: #{total}"

    if total.zero?
      puts "📦 Blob purge: нечего удалять, выходим."
      next
    end

    # 3. Чистим батчами, аккуратно
    purged = 0
    blobs_to_purge.find_each(batch_size: 1000) do |blob|
      purged += 1
      blob.purge_later
      puts "  → queued purge for blob ##{blob.id} (key=#{blob.key}) [#{purged}/#{total}]" if (purged % 1000).zero?
    end

    puts "✅ Blob purge: поставлено в очередь на удаление #{purged} blobs."
  end
end


