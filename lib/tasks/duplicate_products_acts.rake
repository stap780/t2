# rake duplicate_products_acts:save
# Сохраняет acts_by_product в docs/duplicate_products_acts_by_product.md
namespace :duplicate_products_acts do
  desc "Save acts_by_product for duplicate products to docs"
  task save: :environment do
    items4 = Item.joins(variant: :product)
      .joins(:acts)
      .joins("LEFT JOIN varbinds ON varbinds.record_type = 'Variant' AND varbinds.record_id = variants.id AND varbinds.bindable_type = 'Moysklad'")
      .includes(:item_status)
      .where(item_status_id: 3, products: { status: 'draft' })
      .where('varbinds.id IS NULL')

    products_ids = items4.map { |i| i.variant.product.id }
    duplicat = products_ids.group_by(&:itself).transform_values(&:count).select { |_, c| c > 1 }

    acts_by_product = duplicat.keys.each_with_object({}) do |product_id, hash|
      hash[product_id] = Act.joins(items: :variant)
        .where(variants: { product_id: product_id })
        .distinct
        .pluck(:id, :date, :number)
    end

    doc_path = Rails.root.join('docs/duplicate_products_acts_by_product.md')
    header = "# Акты по дублирующимся продуктам\n\n## Список (product_id => акты)\n\n| product_id | акты |\n|------------|------|\n"
    lines = acts_by_product.map { |pid, acts| "| #{pid} | #{acts.map { |a| "#{a[2]} (#{a[1].strftime('%d %b')})" }.join(', ')} |" }
    File.write(doc_path, header + lines.join("\n") + "\n")
    puts "Сохранено #{acts_by_product.size} записей в #{doc_path}"
  end
end
