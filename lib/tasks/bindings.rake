namespace :bindings do
  desc "Перенести Insale-привязки и обновить штрихкоды для вариантов по фиксированному списку штрихкодов"
  task fix_insale_for_barcodes: :environment do
    barcodes = '0000002470078,0000003930113,0000003652541,0000002413990,0000002576251,0000003359778,0000002064291,0000003204535,0000002400884,0000003552490,0000003255148,0000003814604,0000001190328,0000001202076,0000002895932,0000003045206,0000003254097,0000002297354,0000003311332,0000002466040,0000002047201,0000002311357,0000002662879,0000003940631,0000003931134,0000003948507,0000002580968,0000003679753,0000001607666,0000002369846,0000002333113,0000002292618,0000001838848,0000003143407,0000003233177,0000002396194,0000002817798,0000003971369,0000001813388,0000002692920,0000002162881,0000003514542,0000001970128,0000001388534,0000001256369,0000002374284,0000003392966,0000003287675,0000001718829,0000002842370,0000001612981,0000001906028,0000002160818,0000002976372,0000002183817,0000002949666,0000002917719,0000002661902,0000003269077,0000002837932,0000001806663,0000003193341,0000002634623,0000002020464,0000002505084,0000002791364,0000002751160,0000003365687,0000003839744,0000002421704'.split(',').map(&:strip)

    puts "Запускаю обработку штрихкодов: #{barcodes.join('  ')}"

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
        puts "  Продуктов по этому штрихкоду: #{products.size} (ids: #{products.map(&:id).join('  ')})"
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
          puts "  Пропускаю: не нашёл варианты  соответствующие продуктам"
          next
        end

        puts "  Product с картинками:     #{p_with_img.id}  Variant #{v_with_img.id}"
        puts "  Product без картинок:     #{p_without_img.id}  Variant #{v_without_img.id}"

        ApplicationRecord.transaction do
          # 1) Перенос Insale‑bindings у Product
          puts "  Перенос привязок Product #{p_without_img.id} -> Product #{p_with_img.id}"
          p_without_img.bindings.where(bindable_type: "Insale").find_each do |b|
            existing = p_with_img.bindings.find_by(
              bindable_type: b.bindable_type,
              bindable_id:   b.bindable_id
            )

            if existing
              puts "    Product binding #{b.id}: уже есть привязка к этой Insale на Product #{p_with_img.id}  пропускаю"
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
              puts "    Variant binding #{b.id}: уже есть привязка к этой Insale на Variant #{v_with_img.id}  пропускаю"
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
          puts "    Был штрихкод: #{old_barcode.inspect}  стал: #{v_without_img.barcode.inspect}"
        end
      rescue => e
        puts "  ОШИБКА при обработке штрихкода #{bc}: #{e.class} - #{e.message}"
        puts e.backtrace.first(5).join("\n")
      end
    end

    puts "Готово."
  end
end

