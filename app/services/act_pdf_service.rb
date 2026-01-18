require 'prawn'

class ActPdfService
  def initialize(act)
    @act = act
    @use_cyrillic_font = false
  end

  def call
    generate_pdf
  end

  private

  def generate_pdf
    pdf = Prawn::Document.new(
      page_size: 'A4',
      page_layout: :portrait,
      margin: [15, 15, 15, 15]
    )

    setup_fonts(pdf)

    company = @act.company
    strahcompany = @act.strah

    # Шапка: Информация о компании (принимающая сторона)
    font_name = @use_cyrillic_font ? 'Verdana' : 'Helvetica'
    pdf.font(font_name) do
      pdf.text company.title, size: 12, style: :bold if company&.title.present?
      pdf.text company.ur_address, size: 10 if company&.ur_address.present?
      pdf.move_down 10


      # Заголовок акта
      pdf.text "АКТ ПРИЕМА-ПЕРЕДАЧИ № #{@act.id}", size: 12, style: :bold, align: :center
      pdf.move_down 20

      # Секция из двух блоков равной ширины
      start_y = pdf.cursor
      box_width = (pdf.bounds.width - 20) / 2
      spacing = 20
      line_width = box_width * 0.8

      # Левая колонка: Передающая сторона
      pdf.bounding_box([pdf.bounds.left, start_y], width: box_width, height: 70) do
        pdf.text "Передающая сторона", size: 10, style: :bold
        pdf.move_down 6
        
        # Три строки шириной 80% от ширины блока, выровненные по левому краю
        # Высота каждой строки: пустое пространство (9pt) + 3pt + линия + 7pt = ~20pt
        line_start_x = 0
        # Первая строка (пустая, но с такой же высотой как вторая и третья в правом блоке)
        pdf.move_down 9  # Компенсируем отсутствие текста (высота текста ~9pt)
        pdf.move_down 3  # Отступ перед линией (как в строках с текстом)
        pdf.stroke_horizontal_line line_start_x, line_start_x + line_width, at: pdf.cursor
        pdf.move_down 7  # После линии
        
        # Вторая строка
        pdf.move_down 9  # Компенсируем отсутствие текста
        pdf.move_down 3  # Отступ перед линией
        pdf.stroke_horizontal_line line_start_x, line_start_x + line_width, at: pdf.cursor
        pdf.move_down 7  # После линии
        
        # Третья строка
        pdf.move_down 9  # Компенсируем отсутствие текста
        pdf.move_down 3  # Отступ перед линией
        pdf.stroke_horizontal_line line_start_x, line_start_x + line_width, at: pdf.cursor
      end

      # Правая колонка: Принимающая сторона
      right_x = pdf.bounds.left + box_width + spacing
      pdf.bounding_box([right_x, start_y], width: box_width, height: 70) do
        pdf.text "Принимающая сторона", size: 10, style: :bold
        pdf.move_down 6
        
        # Три строки шириной 80% от ширины блока, выровненные по левому краю
        # Высота каждой строки: текст (9pt) + 3pt + линия + 7pt = ~20pt
        line_start_x = 0
        # Первая строка (пустая, но с такой же высотой - добавляем пустое пространство вместо текста)
        pdf.move_down 9  # Компенсируем отсутствие текста (высота текста ~9pt)
        pdf.move_down 3  # Отступ перед линией (как в строках с текстом)
        pdf.stroke_horizontal_line line_start_x, line_start_x + line_width, at: pdf.cursor
        pdf.move_down 7  # После линии
        
        # Вторая строка с текстом
        pdf.text "от имени #{strahcompany&.title || ''}", size: 9
        pdf.move_down 3
        pdf.stroke_horizontal_line line_start_x, line_start_x + line_width, at: pdf.cursor
        pdf.move_down 7
        
        # Третья строка с текстом
        pdf.text "по договору хранения от", size: 9
        pdf.move_down 3
        pdf.stroke_horizontal_line line_start_x, line_start_x + line_width, at: pdf.cursor
      end
      
      # Перемещаем курсор вниз после блока сторон
      pdf.move_cursor_to(start_y - 70)
      pdf.move_down 15

      # Дата акта
      pdf.text "г. Москва", size: 10
      pdf.text @act.date&.strftime('%d/%m/%Y'), size: 10, align: :right
      pdf.move_down 15

      # Текст о передаче
      pdf.text "Передающая сторона передаст Принимающей стороне повреждённые детали, узлы и агрегаты транспортных средств (ТС) в соответствии с нижеперечисленными заказ-нарядами.", size: 10, style: :bold
      pdf.move_down 15

      # Группируем позиции по заявкам (Incase)
      incases = @act.items.includes(:incase).map(&:incase).uniq.compact

      # Минимальная высота для футера с подписями
      # Футер размещается на footer_y = 35 от низа страницы, имеет высоту 25
      # margin bottom = 15, поэтому относительно bounds.bottom футер начинается на высоте 35 - 15 = 20
      # Добавляем отступ (15) для безопасности, чтобы контент не накладывался на футер
      footer_min_height = 20 + 15  # 35 точек от bounds.bottom

      incases.each do |incase|
        # Проверяем доступное место перед добавлением заголовка заявки
        # Заголовок занимает примерно 20-25 точек
        if pdf.cursor < footer_min_height + 25
          pdf.start_new_page
        end

        # Заголовок заявки
        incase_header_data = [
          [
            incase.stoanumber.present? ? "Номер З/Н #{incase.stoanumber}" : "Заявка ##{incase.id}",
            "ТС: #{incase.modelauto || 'Не указано'} (#{incase.carnumber || 'Не указано'})",
            "№ ВД #{incase.unumber} от #{incase.date&.strftime('%d/%m/%Y')}"
          ]
        ]

        pdf.table(incase_header_data, header: false, column_widths: [145, 205, 210]) do |table|
          table.row(0).font_style = :bold
          table.row(0).background_color = 'E0E0E0'
          table.cells.font = font_name
          table.cells.size = 9
        end

        # Позиции этой заявки, включенные в акт
        act_items_from_incase = @act.items.where(incase: incase).order(:title)

        act_items_from_incase.each do |item|
          # Проверяем доступное место перед добавлением каждой позиции
          # Каждая позиция занимает примерно 20-25 точек
          if pdf.cursor < footer_min_height + 25
            pdf.start_new_page
          end

          item_data = [
            [
              { content: "#{item.title} (#{item.katnumber})", colspan: 2 },
              { content: "☐ Да ☐ Нет Примечание: #{item.item_status&.title || ''}", colspan: 1 }
            ]
          ]

          pdf.table(item_data, header: false, column_widths: [205, 145, 210]) do |table|
            table.row(0).borders = [:bottom]
            table.row(0).border_width = 0.5
            table.row(0).border_color = 'CCCCCC'
            table.cells.font = font_name
            table.cells.size = 10
          end
        end

        pdf.move_down 10
      end

      # Подписи в футере страницы
      # Используем repeat для размещения в футере на всех страницах
      pdf.repeat(:all) do
        footer_y = 35
        box_width = (pdf.bounds.width - 20) / 2
        spacing = 20
        line_width = box_width - 10

        # Левая секция: только линия и подпись
        pdf.bounding_box([pdf.bounds.left, footer_y], width: box_width, height: 25) do
          # Линия для подписи
          pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.left + line_width, at: pdf.cursor
          
          pdf.move_down 8
          pdf.text "(подпись)", size: 9
        end

        # Правая секция: только линия и подпись (на том же уровне)
        right_x = pdf.bounds.left + box_width + spacing
        pdf.bounding_box([right_x, footer_y], width: box_width, height: 25) do
          # Линия для подписи
          pdf.stroke_horizontal_line pdf.bounds.left, pdf.bounds.left + line_width, at: pdf.cursor
          
          pdf.move_down 8
          pdf.text "(подпись)", size: 9
        end
      end
    end

    # Добавляем нумерацию страниц внизу справа в формате "CTP X/Y"
    # Используем repeat для контроля размера шрифта разных частей
    pdf.repeat(:all) do
      pdf.bounding_box([pdf.bounds.right - 100, 20], width: 100, height: 20) do
        page_num = pdf.page_number
        total_pages = pdf.page_count rescue nil
        
        if total_pages && total_pages > 0
          # Используем inline_format для разных размеров шрифта
          pdf.text_box "<font size='7'>CTP</font> <font size='9'>#{page_num}/#{total_pages}</font>", 
                       at: [0, 20], 
                       width: 100, 
                       align: :right,
                       inline_format: true,
                       size: 9
        else
          pdf.text_box "<font size='7'>CTP</font> <font size='9'>#{page_num}</font>", 
                       at: [0, 20], 
                       width: 100, 
                       align: :right,
                       inline_format: true,
                       size: 9
        end
      end
    end

    pdf.render
  end

  def setup_fonts(pdf)
    # Настройка шрифтов с поддержкой кириллицы
    # Используем Verdana из папки public/fonts
    font_path = Rails.root.join('public', 'fonts')

    verdana_normal = font_path.join('verdana.ttf').to_s
    verdana_bold = font_path.join('verdanab.ttf').to_s
    verdana_italic = font_path.join('verdanai.ttf').to_s

    # Проверяем наличие шрифтов и используем их, если доступны
    if File.exist?(verdana_normal)
      pdf.font_families.update(
        'Verdana' => {
          normal: verdana_normal,
          bold: File.exist?(verdana_bold) ? verdana_bold : verdana_normal,
          italic: File.exist?(verdana_italic) ? verdana_italic : verdana_normal,
          bold_italic: File.exist?(verdana_bold) ? verdana_bold : verdana_normal
        }
      )
      @use_cyrillic_font = true
      Rails.logger.info "Verdana fonts loaded from public/fonts for Act PDF"
    else
      # Fallback на Helvetica, если Verdana недоступен
      pdf.font_families.update(
        'Helvetica' => {
          normal: 'Helvetica',
          bold: 'Helvetica-Bold',
          italic: 'Helvetica-Oblique',
          bold_italic: 'Helvetica-BoldOblique'
        }
      )
      @use_cyrillic_font = false
      Rails.logger.warn "Verdana fonts not found in public/fonts, using Helvetica (no Cyrillic support)"
    end
  end
end

