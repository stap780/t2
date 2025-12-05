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
      pdf.text company.title, size: 14, style: :bold if company&.title.present?
      pdf.text company.ur_address, size: 10 if company&.ur_address.present?
      pdf.move_down 10

      # Информация о страховой компании (передающая сторона)
      pdf.text "Передающая сторона:", size: 10, style: :bold
      pdf.text strahcompany.title, size: 10 if strahcompany&.title.present?
      pdf.text strahcompany.ur_address, size: 10 if strahcompany&.ur_address.present?
      pdf.move_down 15

      # Заголовок акта
      pdf.text "АКТ ПРИЕМА-ПЕРЕДАЧИ", size: 16, style: :bold, align: :center
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

      incases.each do |incase|
        # Заголовок заявки
        incase_header_data = [
          [
            incase.stoanumber.present? ? "Номер З/Н #{incase.stoanumber}" : "Заявка ##{incase.id}",
            "ТС: #{incase.modelauto || 'Не указано'} (#{incase.carnumber || 'Не указано'})",
            "№ ВД #{incase.unumber} от #{incase.date&.strftime('%d/%m/%Y')}"
          ]
        ]

        pdf.table(incase_header_data, header: false, column_widths: [100, 225, 175]) do |table|
          table.row(0).font_style = :bold
          table.row(0).background_color = 'E0E0E0'
          table.cells.font = font_name
        end

        # Позиции этой заявки, включенные в акт
        act_items_from_incase = @act.items.where(incase: incase).order(:title)

        act_items_from_incase.each do |item|
          item_data = [
            [
              { content: "#{item.title} (#{item.katnumber})", colspan: 2 },
              { content: "☐ Да ☐ Нет Примечание: #{item.item_status&.title || ''}", colspan: 1 }
            ]
          ]

          pdf.table(item_data, header: false, column_widths: [225, 100, 175]) do |table|
            table.row(0).borders = [:bottom]
            table.row(0).border_width = 0.5
            table.row(0).border_color = 'CCCCCC'
            table.cells.font = font_name
          end
        end

        pdf.move_down 10
      end

      # Подписи
      pdf.move_down 20
      pdf.text "Подписи:", size: 10, style: :bold
      pdf.move_down 30

      pdf.text "Передающая сторона:", size: 10
      pdf.move_down 40

      pdf.text "Принимающая сторона:", size: 10
      pdf.move_down 40
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

