# Загрузка картинок товара из CarParts по item_id.
# Использует Product::ImportImage и JSON http://138.197.52.153/items/:id.json
#
# Использование:
#   rake product:import_item_images[784094,panaet80@gmail.com,071080]
#   system("rake product:import_item_images[784094,panaet80@gmail.com,071080]")
#
namespace :product do
  CARPARTS_BASE = 'http://138.197.52.153'

  desc "Import images for product by carpats item_id (item_id,email,password)"
  task :import_item_images, [:item_id, :email, :password] => :environment do |_t, args|
    item_id = args[:item_id].to_i
    email = args[:email]
    password = args[:password]

    if item_id.zero? || email.blank? || password.blank?
      puts "Usage: rake product:import_item_images[ITEM_ID,EMAIL,PASSWORD]"
      puts "Example: rake product:import_item_images[784094,panaet80@gmail.com,071080]"
      exit 1
    end

    url = "#{CARPARTS_BASE}/items/#{item_id}.json"

    puts "Fetching #{url}..."
    json_str = IncaseJsonImporter.fetch_json_via_curl(url, email, password)

    if json_str.strip.start_with?('<!') || json_str.strip.start_with?('<html')
      puts "Error: Received HTML instead of JSON (auth failed?)"
      exit 1
    end

    item_data = JSON.parse(json_str)
    barcode = item_data['barcode']

    images = item_data['images'] || []
    images = images.sort_by { |img| img.is_a?(Hash) ? img['position'].to_i : 0 }
    image_urls = images.map do |img|
      raw = img.is_a?(Hash) ? (img['image'] || img['url']) : img.to_s
      next if raw.blank?
      url = raw.is_a?(Hash) ? (raw['url'] || raw['original']) : raw.to_s.strip
      next if url.blank?
      url.start_with?('http') ? url : "#{CARPARTS_BASE}#{url}"
    end.compact

    if image_urls.empty?
      puts "No images found in JSON"
      exit 0
    end

    variant = Variant.joins(:product).find_by(barcode: barcode)
    product = variant&.product

    unless product
      puts "Product not found for barcode=#{barcode}"
      exit 1
    end

    puts "Importing #{image_urls.size} images to product ##{product.id} (#{product.title})..."
    result = Product::ImportImage.new(product, image_urls).call

    if result[:success]
      puts "Done. Attached: #{result[:attached]}, reordered: #{result[:reordered]}"
    else
      puts "Error: #{result[:error]}"
      exit 1
    end
  end
end
