# frozen_string_literal: true
#
# Проверка экспорта: какие товары из scope отсутствуют в XML-файле.
# Id в XML = product.id или feature "Старый ID" (если есть и не пустой).
#
# Запуск: bin/rails export:check_missing
# Или:   bin/rails 'export:check_missing[9]'
#
namespace :export do
  desc "Check which products from scope are missing in export XML (default: export 9)"
  task :check_missing, [:export_id] => :environment do |_t, args|
    require 'open-uri'
    require 'nokogiri'

    def real_id(product)
      val = product.features_to_h['Старый ID']
      val.present? && val.to_s != '' ? val.to_s : product.id.to_s
    end

    export_id = (args[:export_id] || 9).to_i
    export = Export.find(export_id)
    puts "Export ##{export.id} (#{export.name})"

    url = "https://cpt.dizauto.ru/exports/export-#{export_id}.xml"
    puts "Fetching #{url}..."
    xml_content = URI.open(url, read_timeout: 90).read
    doc = Nokogiri::XML(xml_content)

    file_ids = doc.xpath("//Ad/Id").map { |el| el.text.to_s.strip }.reject(&:blank?).to_set

    scope_products = Product.active.yes_quantity.yes_price.with_images.distinct

    missing_ids = []
    scope_products.includes(features: [:property, :characteristic]).find_each do |p|
      rid = real_id(p)
      missing_ids << p.id unless file_ids.include?(rid)
    end

    puts "\n=== Результаты (сопоставление по real_id) ==="
    puts "Scope: #{scope_products.count} товаров"
    puts "В файле (уникальных Ad): #{file_ids.size}"
    puts "Нет в файле (missing): #{missing_ids.size}"

    if missing_ids.any?
      puts "\n=== Первые 20 отсутствующих product IDs ==="
      puts missing_ids.first(20).inspect

      puts "\n=== Примеры отсутствующих товаров ==="
      Product.where(id: missing_ids.first(10)).includes(features: [:property, :characteristic]).each do |p|
        rid = real_id(p)
        puts "  #{p.id}: #{p.title[0..45]}... | real_id=#{rid}"
      end

      puts "\nВсе #{missing_ids.size} отсутствующих ID:"
      puts missing_ids.sort.join("\n")
    end
  end
end
