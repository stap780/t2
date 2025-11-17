require 'barby'
require 'barby/barcode/ean_13'
require 'barby/outputter/png_outputter'
require 'base64'

class EtiketkaService
  def initialize(variant)
    @variant = variant
    @error_message = []
  end

  def call
    pdf = generate_pdf
    return [false, @error_message] if pdf.nil?

    blob = upload_pdf(pdf)
    if blob
      [true, blob]
    else
      [false, @error_message]
    end
  end

  private

  def generate_pdf
    # Точное соответствие параметрам из dizauto:
    # page_height: 41 мм, page_width: 65 мм
    # margin: { top: 1, bottom: 5, left: 1, right: 1 }
    # 1 мм = 2.83465 точек (PostScript points)
    
    page_width_mm = 65   # page_width из dizauto
    page_height_mm = 41  # page_height из dizauto
    page_width_pt = page_width_mm * 2.83465
    page_height_pt = page_height_mm * 2.83465

    # Отступы в миллиметрах (как в dizauto)
    margin_top_mm = 1
    margin_bottom_mm = 5
    margin_left_mm = 1
    margin_right_mm = 1
    
    # Конвертируем отступы в точки
    margin_top_pt = margin_top_mm * 2.83465
    margin_bottom_pt = margin_bottom_mm * 2.83465
    margin_left_pt = margin_left_mm * 2.83465
    margin_right_pt = margin_right_mm * 2.83465

    pdf = Prawn::Document.new(
      page_size: [page_width_pt, page_height_pt], # [width, height] в точках
      margin: [margin_top_pt, margin_right_pt, margin_bottom_pt, margin_left_pt],
      page_layout: :portrait
    )

    # Вычисляем доступную высоту для контента (исключая footer)
    footer_height = 10
    available_height = pdf.bounds.height - footer_height - 5

    # Название продукта (обрезанное до 26 символов) - уменьшаем высоту для экономии места
    product_title = @variant.product.title.to_s[0..25] || ''
    pdf.text_box product_title, 
                 at: [pdf.bounds.left, pdf.bounds.top], 
                 width: pdf.bounds.width,
                 height: 10,
                 size: 14, 
                 align: :center, 
                 valign: :top,
                 overflow: :shrink_to_fit

    # Штрих-код (PNG изображение) - максимально уменьшаем отступы
    barcode_y = pdf.bounds.top - 12
    barcode_text_y = nil
    
    if @variant.barcode.present? && @variant.barcode.size == 13
      insert_barcode_image(pdf, barcode_y)
      # Опускаем числовой код ниже (увеличиваем расстояние с 50 до 60)
      barcode_text_y = barcode_y - 60
    end

    # Числовой код штрих-кода (крупным шрифтом)
    if @variant.barcode.present? && barcode_text_y
      pdf.text_box @variant.barcode.to_s, 
                   at: [pdf.bounds.left, barcode_text_y], 
                   width: pdf.bounds.width,
                   height: 13,
                   size: 12, 
                   align: :center, 
                   valign: :top,
                   style: :bold,
                   overflow: :shrink_to_fit
    end

    # SKU
    if @variant.sku.present?
      sku_y = barcode_text_y ? barcode_text_y - 20 : pdf.bounds.top - 60
      pdf.text_box "Ор.Н. #{@variant.sku}", 
                   at: [pdf.bounds.left, sku_y], 
                   width: pdf.bounds.width,
                   height: 12,
                   size: 12, 
                   align: :center, 
                   valign: :top,
                   overflow: :shrink_to_fit
    end

    # Footer (точное соответствие dizauto: font_size: 12, center: 'www.dizauto.ru   84951503437')
    # Размещаем footer внизу страницы в области margin_bottom
    footer_text = "www.dizauto.ru   84951503437"
    footer_font_size = 12
    pdf.text_box footer_text, 
                 at: [pdf.bounds.left, footer_height], 
                 width: pdf.bounds.width,
                 height: footer_height,
                 size: footer_font_size, 
                 align: :center,
                 valign: :center,
                 overflow: :shrink_to_fit

    pdf.render
  rescue => e
    @error_message << "PDF generation error: #{e.message}"
    Rails.logger.error "EtiketkaService PDF generation error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  def insert_barcode_image(pdf, y_position)
    return unless @variant.barcode.present? && @variant.barcode.size == 13

    # Создать штрих-код через barby
    barcode = Barby::EAN13.new(@variant.barcode[0...-1])
    barcode_png = Barby::PngOutputter.new(barcode)
    image_data = barcode_png.to_png

    # Сохранить во временный файл
    temp_file = Tempfile.new(['barcode', '.png'])
    temp_file.binmode
    temp_file.write(image_data)
    temp_file.rewind

    # Вставить в PDF (максимально увеличиваем размер штрих-кода, минимальные отступы)
    # Вычисляем максимальную ширину с минимальными отступами (почти без отступов)
    max_width = pdf.bounds.width - 0.5
    barcode_width = [max_width, 170].min # Увеличено с 150 до 170
    barcode_height = 55 # Увеличено с 50 до 55 для лучшей читаемости
    
    # Позиционируем изображение по центру по горизонтали
    x_position = pdf.bounds.left + (pdf.bounds.width - barcode_width) / 2
    pdf.image temp_file.path, 
              at: [x_position, y_position], 
              width: barcode_width,
              height: barcode_height

    temp_file.close
    temp_file.unlink
  rescue => e
    @error_message << "Barcode generation error: #{e.message}"
    Rails.logger.error "EtiketkaService barcode generation error: #{e.message}"
  end

  def upload_pdf(pdf)
    file = Tempfile.new(['etiketka', '.pdf'], encoding: 'ascii-8bit')
    file.write(pdf)
    file.rewind

    blob = ActiveStorage::Blob.create_and_upload!(
      io: file,
      filename: "etiketka_#{@variant.id}.pdf",
      content_type: 'application/pdf'
    )

    file.close
    file.unlink

    blob
  rescue StandardError => e
    @error_message << "Upload error: #{e.message}"
    Rails.logger.error "EtiketkaService upload error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end
end

