namespace :bindings do
  desc "Перенести Insale-привязки и обновить штрихкоды для вариантов по списку штрихкодов"
  task :fix_insale_for_barcodes, [:barcodes] => :environment do |_t, args|
    if args[:barcodes].blank?
      puts "Нужно передать список штрихкодов через запятую."
      puts "Пример:"
      puts "  rake 'bindings:fix_insale_for_barcodes[0000003775936,0000002463568,0000003058848]' RAILS_ENV=production"
      exit 1
    end

    barcodes = args[:barcodes].split(",").map(&:strip).reject(&:blank?)

    puts "Запускаю обработку штрихкодов: #{barcodes.join(', ')}"

    barcodes.each do |bc|
      puts "=============================="
      puts "Обрабатываем штрихкод: #{bc}"

      begin
        variants = Variant.
          includes(:bindings, product: [:images, :bindings]).
          where(barcode: bc)

        puts "  Найдено вариантов: #{variants.size}"
        unless variants.size == 2
          puts "  Пропускаю: вариантов не 2"
          next
        end

        products = variants.map(&:product).uniq
        puts "  Продуктов по этому штрихкоду: #{products.size} (ids: #{products.map(&:id).join(', ')})"
        unless products.size == 2
          puts "  Пропускаю: продуктов не 2"
          next
        end

        p_with_img    = products.find { |p| p.images.any? }
        p_without_img = products.find { |p| p.images.empty? }

        unless p_with_img && p_without_img
          puts "  Пропускаю: не могу однозначно определить продукт с/без картинок"
          products.each do |p|
            puts "    Product #{p.id}: images_count=#{p.images.size}"
          end
          next
        end

        v_with_img    = variants.find { |v| v.product_id == p_with_img.id }
        v_without_img = variants.find { |v| v.product_id == p_without_img.id }

        unless v_with_img && v_without_img
          puts "  Пропускаю: не нашёл варианты, соответствующие продуктам"
          next
        end

        puts "  Product с картинками:     #{p_with_img.id}, Variant #{v_with_img.id}"
        puts "  Product без картинок:     #{p_without_img.id}, Variant #{v_without_img.id}"

        ApplicationRecord.transaction do
          # 1) Перенос Insale‑bindings у Product
          puts "  Перенос привязок Product #{p_without_img.id} -> Product #{p_with_img.id}"
          p_without_img.bindings.where(bindable_type: "Insale").find_each do |b|
            existing = p_with_img.bindings.find_by(
              bindable_type: b.bindable_type,
              bindable_id:   b.bindable_id
            )

            if existing
              puts "    Product binding #{b.id}: уже есть привязка к этой Insale на Product #{p_with_img.id}, пропускаю"
            else
              old_record_id = b.record_id
              b.update!(record: p_with_img)
              puts "    Product binding #{b.id}: перенесён (record_id #{old_record_id} -> #{b.record_id})"
            end
          end

          # 2) Перенос Insale‑bindings у Variant
          puts "  Перенос привязок Variant #{v_without_img.id} -> Variant #{v_with_img.id}"
          v_without_img.bindings.where(bindable_type: "Insale").find_each do |b|
            existing = v_with_img.bindings.find_by(
              bindable_type: b.bindable_type,
              bindable_id:   b.bindable_id
            )

            if existing
              puts "    Variant binding #{b.id}: уже есть привязка к этой Insale на Variant #{v_with_img.id}, пропускаю"
            else
              old_record_id = b.record_id
              b.update!(record: v_with_img)
              puts "    Variant binding #{b.id}: перенесён (record_id #{old_record_id} -> #{b.record_id})"
            end
          end

          # 3) Обновляем штрихкод у варианта без картинок
          puts "  Обновляем штрихкод у Variant #{v_without_img.id}"
          old_barcode = v_without_img.barcode
          v_without_img.create_barcode
          v_without_img.reload
          puts "    Был штрихкод: #{old_barcode.inspect}, стал: #{v_without_img.barcode.inspect}"
        end
      rescue => e
        puts "  ОШИБКА при обработке штрихкода #{bc}: #{e.class} - #{e.message}"
        puts e.backtrace.first(5).join("\n")
      end
    end

    puts "Готово."
  end
end

