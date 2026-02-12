# frozen_string_literal: true

# 4 ключа доступа к InSales API
INSALES_CREDENTIALS = [
  { api_key: "5418f142e90fb0f4e8bdcd607f4d4b5b", api_password: "c0b6a8ef920e879bed5c4f3376355335", api_link: "dizauto.myinsales.ru" },
  { api_key: "db2e2cd5fed4dda9b62af7e929ab2057", api_password: "62d916be7755d383f8803ea4d0ccd1f8", api_link: "dizauto.myinsales.ru" },
  { api_key: "071ecaa90a60b580722e76ad000db439", api_password: "4b5a0ccf83411c960d2c505850bca79f", api_link: "dizauto.myinsales.ru" },
  { api_key: "a6d7c2ff68a582a14d313e3c017ff110", api_password: "18d0cafc6aec640b70c610e9b8a783f2", api_link: "dizauto.myinsales.ru" }
].freeze

namespace :insales do
  desc "Синхронизация varbind: получить варианты из InSales API по всем 4 ключам, найти в БД по штрихкоду, добавить связь varbind"
  task varbind_sync: :environment do
    puts "🔄 Синхронизация varbind InSales (4 ключа)"
    puts "⏰ Время начала: #{Time.zone.now}"

    stats = { processed: 0, created: 0, skipped: 0, not_found: 0, errors: 0 }

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
    puts "   Создано varbind: #{stats[:created]}"
    puts "   Пропущено (уже есть varbind): #{stats[:skipped]}"
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
          process_insales_variant(insale, ins_variant, stats)
        end
      end
      
      sleep 0.8

      puts "   Страница #{page}, ключ #{key_idx + 1}/4, товаров #{products.size}"
      page += 1
    end
  rescue StandardError => e
    puts "   ❌ Ошибка: #{e.class} #{e.message}"
    stats[:errors] += 1
    Rails.logger.error "InsalesVarbindSync: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def process_insales_variant(insale, ins_variant, stats)
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
      return
    end

    Varbind.create!(record: variant, bindable: insale, value: ext_variant_id)
    stats[:created] += 1
  rescue ActiveRecord::RecordInvalid => e
    stats[:errors] += 1
    Rails.logger.warn "InsalesVarbindSync: не удалось создать varbind: #{e.message}"
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
      sleep 0.8
    end

    puts "\n📊 Итого: обновлено #{stats[:updated]} из #{stats[:total]} вариантов"
    puts "⏰ Время завершения: #{Time.zone.now}"
  rescue StandardError => e
    puts "   ❌ Ошибка: #{e.class} #{e.message}"
    Rails.logger.error "InsalesPricesUpdate: #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    raise
  end
end


# rails insales:varbind_sync
# rails insales:prices_update