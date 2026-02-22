# frozen_string_literal: true

# 4 ключа доступа к InSales API
INSALES_CREDENTIALS = [
  {
    api_key: Rails.application.credentials.dig(:insales, :key1),
    api_password: Rails.application.credentials.dig(:insales, :pass1),
    api_link: "dizauto.myinsales.ru"
  },
  {
    api_key: Rails.application.credentials.dig(:insales, :key2),
    api_password: Rails.application.credentials.dig(:insales, :pass2),
    api_link: "dizauto.myinsales.ru"
  },
  {
    api_key: Rails.application.credentials.dig(:insales, :key3),
    api_password: Rails.application.credentials.dig(:insales, :pass3),
    api_link: "dizauto.myinsales.ru"
  },
  {
    api_key: Rails.application.credentials.dig(:insales, :key4),
    api_password: Rails.application.credentials.dig(:insales, :pass4),
    api_link: "dizauto.myinsales.ru"
  }
].freeze

namespace :insales do
  desc "Синхронизация varbind: получить варианты из InSales API по всем 4 ключам, найти в БД по штрихкоду, добавить связь varbind"
  task varbind_sync: :environment do
    puts "🔄 Синхронизация varbind InSales (4 ключа)"
    puts "⏰ Время начала: #{Time.zone.now}"

    stats = { processed: 0, created: 0, skipped: 0, not_found: 0, errors: 0, product_created: 0, product_skipped: 0 }

    # Используем Insale, уже настроенный в базе (для bindable в varbind)
    insale = Insale.first
    unless insale
      puts "❌ Нет записи Insale в базе. Создайте и настройте Insale."
      next
    end

    # По 100 товаров, каждый батч своим ключом (4 ключа к одному магазину)
    sync_varbinds_single_store(insale, stats)

    puts "\n📊 Итого:"
    puts "   Обработано вариантов из API: #{stats[:processed]}"
    puts "   Создано varbind (Variant): #{stats[:created]}"
    puts "   Создано varbind (Product): #{stats[:product_created]}"
    puts "   Пропущено (уже есть varbind): #{stats[:skipped]}"
    puts "   Пропущено Product (уже есть varbind): #{stats[:product_skipped]}"
    puts "   Не найдено в БД по штрихкоду: #{stats[:not_found]}"
    puts "   Ошибок: #{stats[:errors]}"
    puts "⏰ Время завершения: #{Time.zone.now}"
  end

  def sync_varbinds_single_store(insale, stats)
    batch_size = 100
    page = 1
    max_pages = 400 # для теста

    loop do
      break if page > max_pages
      key_idx = (page - 1) % INSALES_CREDENTIALS.size
      creds = INSALES_CREDENTIALS[key_idx]

      # Инициализируем API текущим ключом
      InsalesApi::App.api_key = creds[:api_key]
      InsalesApi::App.configure_api(creds[:api_link], creds[:api_password])

      products = InsalesApi.wait_retry do
        InsalesApi::Product.all(params: { per_page: batch_size, page: page })
      end

      break if products.empty?

      products.each do |ins_product|
        variants = Array(ins_product.try(:variants))
        variants.each do |ins_variant|
          process_insales_variant(insale, ins_product, ins_variant, stats)
        end
      end
      
      sleep 0.1

      puts "   Страница #{page}, ключ #{key_idx + 1}/4, товаров #{products.size}"
      page += 1
    end
  rescue StandardError => e
    puts "   ❌ Ошибка: #{e.class} #{e.message}"
    stats[:errors] += 1
    Rails.logger.error "InsalesVarbindSync: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def process_insales_variant(insale, ins_product, ins_variant, stats)
    stats[:processed] += 1

    # В InSales штрихкод хранится в поле sku
    barcode = (ins_variant.try(:sku) || ins_variant.try(:[], 'sku')).to_s.strip
    ext_variant_id = ins_variant.try(:id).to_s.presence

    if barcode.blank?
      return
    end

    unless ext_variant_id
      return
    end

    # Найти наш вариант по штрихкоду (из sku InSales)
    variant = Variant.find_by_barcode(barcode)
    unless variant
      stats[:not_found] += 1
      return
    end

    # Уже есть varbind для этого external id в рамках данного Insale?
    existing = Varbind.find_by(bindable: insale, value: ext_variant_id)
    if existing
      if existing.record != variant
        existing.update!(record: variant)  # исправить привязку
      end
      stats[:skipped] += 1
      ensure_product_varbind(insale, ins_product, variant, stats)
      return
    end

    # Проверить, нет ли уже varbind для этого варианта и insale
    existing_binding = variant.bindings.find_by(bindable: insale)
    if existing_binding
      # Обновить value, если он другой (на случай рассинхронизации)
      if existing_binding.value != ext_variant_id
        existing_binding.update!(value: ext_variant_id)
      end
      stats[:skipped] += 1
      ensure_product_varbind(insale, ins_product, variant, stats)
      return
    end

    Varbind.create!(record: variant, bindable: insale, value: ext_variant_id)
    stats[:created] += 1
    ensure_product_varbind(insale, ins_product, variant, stats)
  rescue ActiveRecord::RecordInvalid => e
    stats[:errors] += 1
    Rails.logger.warn "InsalesVarbindSync: не удалось создать varbind: #{e.message}"
  end

  def ensure_product_varbind(insale, ins_product, variant, stats)
    product = variant.product
    ext_product_id = (ins_product.try(:id) || ins_product.try(:[], 'id')).to_s.presence
    return if ext_product_id.blank? || product.blank?

    existing_product_binding = product.bindings.find_by(bindable: insale)
    if existing_product_binding
      if existing_product_binding.value != ext_product_id
        existing_product_binding.update!(value: ext_product_id)
      end
      stats[:product_skipped] += 1
      return
    end

    Varbind.create!(record: product, bindable: insale, value: ext_product_id)
    stats[:product_created] += 1
  rescue ActiveRecord::RecordInvalid => e
    stats[:errors] += 1
    Rails.logger.warn "InsalesVarbindSync: не удалось создать varbind для Product: #{e.message}"
  end

  desc "Обновить цену и количество в InSales по varbind через variants_group_update"
  task prices_update: :environment do
    puts "🔄 Обновление цен и остатков в InSales (variants_group_update)"
    puts "⏰ Время начала: #{Time.zone.now}"

    insale = Insale.first
    unless insale
      puts "❌ Нет записи Insale в базе. Создайте и настройте Insale."
      next
    end

    stats = { total: 0, updated: 0, errors: 0 }
    batch_size = 100

    varbinds = Varbind.where(
      bindable_type: "Insale",
      bindable_id: insale.id,
      record_type: "Variant"
    ).includes(:record)

    variants_data = varbinds.filter_map do |vb|
      next unless vb.record.is_a?(Variant)

      variant = vb.record
      {
        id: vb.value.to_i,
        price: variant.price.to_f,
        quantity: variant.quantity.to_i
      }
    end

    stats[:total] = variants_data.size

    if variants_data.empty?
      puts "   Нет вариантов с varbind для InSales."
      next
    end

    variants_data.each_slice(batch_size).with_index do |batch, idx|
      key_idx = idx % INSALES_CREDENTIALS.size
      creds = INSALES_CREDENTIALS[key_idx]

      InsalesApi::App.api_key = creds[:api_key]
      InsalesApi::App.configure_api(creds[:api_link], creds[:api_password])

      InsalesApi.wait_retry do
        InsalesApi::Product.variants_group_update(batch)
      end

      stats[:updated] += batch.size
      puts "   Батч #{idx + 1}, ключ #{key_idx + 1}/4, обновлено #{batch.size} вариантов"
      sleep 0.1
    end

    puts "\n📊 Итого: обновлено #{stats[:updated]} из #{stats[:total]} вариантов"
    puts "⏰ Время завершения: #{Time.zone.now}"
  rescue StandardError => e
    puts "   ❌ Ошибка: #{e.class} #{e.message}"
    Rails.logger.error "InsalesPricesUpdate: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    raise
  end

  desc "Синхронизация изображений: товары InSales без фото (updated_since N дней) — добавить из приложения"
  task images_sync: :environment do
    puts "🔄 Синхронизация изображений InSales"
    puts "⏰ Время начала: #{Time.zone.now}"

    insale = Insale.first
    unless insale
      puts "❌ Нет записи Insale в базе. Создайте и настройте Insale."
      next
    end

    days_back = (ENV['DAYS'] || 3).to_i
    stats = { processed: 0, images_added: 0, skipped: 0, not_found: 0, errors: 0 }

    sync_images_single_store(insale, days_back, stats)

    puts "\n📊 Итого:"
    puts "   Обработано товаров: #{stats[:processed]}"
    puts "   Добавлено изображений: #{stats[:images_added]}"
    puts "   Пропущено (уже есть фото): #{stats[:skipped]}"
    puts "   Не найдено в БД (нет varbind): #{stats[:not_found]}"
    puts "   Ошибок: #{stats[:errors]}"
    puts "⏰ Время завершения: #{Time.zone.now}"
  rescue StandardError => e
    puts "   ❌ Ошибка: #{e.class} #{e.message}"
    Rails.logger.error "InsalesImagesSync: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    raise
  end

  def sync_images_single_store(insale, days_back, stats)
    batch_size = 250
    page = 1
    max_pages = 100
    since_str = days_back.days.ago.strftime("%Y-%m-%dT%H:%M:%S%:z")

    loop do
      break if page > max_pages

      key_idx = (page - 1) % INSALES_CREDENTIALS.size
      creds = INSALES_CREDENTIALS[key_idx]

      InsalesApi::App.api_key = creds[:api_key]
      InsalesApi::App.configure_api(creds[:api_link], creds[:api_password])

      products = InsalesApi.wait_retry do
        InsalesApi::Product.find(:all, params: {
          per_page: batch_size,
          page: page,
          updated_since: since_str
        })
      end

      break if products.blank?

      products.each { |ins_product| process_insales_product_images(insale, ins_product, stats) }

      sleep 0.1
      puts "   Страница #{page}, ключ #{key_idx + 1}/4, товаров #{products.size}"
      page += 1

      break if products.size < batch_size
    end
  rescue StandardError => e
    puts "   ❌ Ошибка: #{e.class} #{e.message}"
    stats[:errors] += 1
    Rails.logger.error "InsalesImagesSync: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def process_insales_product_images(insale, ins_product, stats)
    stats[:processed] += 1
    ext_product_id = (ins_product.try(:id) || ins_product.try(:[], 'id')).to_s.presence

    ins_images = Array(ins_product.try(:images))
    unless ins_images.empty?
      stats[:skipped] += 1
      return
    end

    return if ext_product_id.blank?

    varbind = Varbind.find_by(bindable: insale, record_type: 'Product', value: ext_product_id)
    unless varbind&.record.is_a?(Product)
      stats[:not_found] += 1
      return
    end

    product = varbind.record
    ordered_images = product.images.order(:position).select { |img| img.file.attached? }
    return if ordered_images.empty?

    ins_image_ids = []
    ordered_images.each do |img|
      im = InsalesApi::Image.new(
        attachment: Base64.encode64(img.file.download),
        filename: img.file.filename.to_s,
        title: img.file.filename.to_s,
        product_id: ext_product_id.to_i
      )
      im.save
      ins_image_ids << im.id
    end

    ins_variant = Array(ins_product.try(:variants)).first
    if ins_variant && ins_image_ids.any?
      ins_variant.image_ids = ins_image_ids
      ins_variant.save
    end

    stats[:images_added] += ins_image_ids.size
  rescue StandardError => e
    stats[:errors] += 1
    Rails.logger.warn "InsalesImagesSync: не удалось добавить изображения для product #{ext_product_id}: #{e.message}"
  end
end


# rails insales:varbind_sync
# rails insales:prices_update
# rails insales:images_sync
# DAYS=7 rails insales:images_sync  # за последние 7 дней