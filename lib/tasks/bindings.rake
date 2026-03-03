namespace :bindings do
  desc "Перенести Insale-привязки и обновить штрихкоды для вариантов по фиксированному списку штрихкодов"
  task fix_insale_for_barcodes: :environment do
    barcodes = '0000002610733,0000002781464,0000003294215,0000003688403,0000003400111,0000003463109,0000003557877,0000002641454,0000002040721,0000002240121,0000002720166,0000003640272,0000003620014,0000002500034,0000003080160,0000003687581,0000003373255,0000003743904,0000002754918,0000002382883,0000002249179,0000001994797,0000003347232,0000003165355,0000003664810,0000002039978,0000003019979,0000003831298,0000003544631,0000002396187,0000003247839,0000002490793,0000003349403,0000002856056,0000003246856,0000002882352,0000002017921,0000003872291,0000003580509,0000003976876,0000003778678,0000003567395,0000003157817,0000003818534,0000003271346,0000001920550,0000002163239,0000002840178,0000003527436,0000003534939,0000003500521,0000003308356,0000002878188,0000003740224,0000003681060,0000003633601,0000002668048,0000002294346,0000003445037,0000003081938,0000002995915,0000001523331,0000003575048,0000001044423,0000001317206,0000001444483,0000003507414,0000002575438,0000001111910,0000003256114,0000001902433,0000002300115,0000002464404,0000003196823,0000001610420,0000003104316,0000003656693,0000003652725,0000002233031,0000003427842,0000002502885,0000003670576,0000001626100,0000003565728,0000002388472,0000003735770,0000003964446,0000003469859,0000001625073,0000003374818,0000002557618,0000001672480,0000002543338,0000002231525,0000003342466'.split(',').map(&:strip)

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

