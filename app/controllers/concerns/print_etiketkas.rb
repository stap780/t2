module PrintEtiketkas
  extend ActiveSupport::Concern

  def print_etiketkas
    # Определяем параметры на основе контроллера
    respond_to do |format|
      format.pdf do
        record, record_name, fallback_path, file_identifier = print_etiketkas_params
        
        # Получаем ID всех вариантов из записи
        variant_ids = get_valid_variant_ids_from_record(record)
        
        if variant_ids.empty?
          flash[:alert] = "В #{record_name} нет позиций с вариантами товаров"
          redirect_back(fallback_location: fallback_path)
          return
        end
        
        print_etiketkas_from_variant_ids(variant_ids, fallback_path: fallback_path, file_identifier: file_identifier, record_name: record_name)
      end
      format.html do
        record, record_name, fallback_path, file_identifier = print_etiketkas_params
        
        # Получаем ID всех вариантов из записи
        variant_ids = get_valid_variant_ids_from_record(record)
        
        if variant_ids.empty?
          flash[:alert] = "В #{record_name} нет позиций с вариантами товаров"
          redirect_back(fallback_location: fallback_path)
          return
        end
        
        print_etiketkas_from_variant_ids(variant_ids, fallback_path: fallback_path, file_identifier: file_identifier, record_name: record_name)
      end
    end
  end

  def bulk_print_etiketkas
    # Для продуктов и других моделей с вариантами
    if params[:print_type] == 'selected' && !params[items].present?
      flash.now[:error] = 'Выберите товары'
      render turbo_stream: [
        render_turbo_flash
      ]
      return
    end
    
    variant_ids = get_valid_variant_ids_for_bulk_print
    
    if variant_ids.empty?
      flash.now[:error] = "Нет вариантов для печати"
      render turbo_stream: [
        render_turbo_flash
      ]
      return
    end
    
    # Генерируем PDF синхронно
    require 'combine_pdf'
    variants = Variant.where(id: variant_ids)
    combined_pdf = CombinePDF.new
    
    variants.each do |variant|
      variant.generate_etiketka unless variant.etiketka.attached?
      if variant.etiketka.attached?
        pdf_data = variant.etiketka.download
        combined_pdf << CombinePDF.parse(pdf_data)
      end
    end
    
    if combined_pdf.pages.empty?
      flash.now[:error] = "Не удалось сгенерировать этикетки"
      render turbo_stream: [
        render_turbo_flash
      ]
      return
    end
    
    # Сохраняем PDF в Active Storage
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = "etiketkas_#{controller_name.singularize}_#{timestamp}.pdf"
    
    # Создаем временный blob
    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(combined_pdf.to_pdf),
      filename: filename,
      content_type: 'application/pdf'
    )
    
    # Сохраняем blob в переменную экземпляра для использования в partial
    @pdf_blob = blob
    
    # Обновляем offcanvas с ссылкой на скачивание
    render turbo_stream: [
      turbo_stream.update('offcanvas', template: 'shared/download_pdf'),
      turbo_stream.set_unchecked(targets: '.checkboxes')
    ]
  rescue => e
    Rails.logger.error "#{self.class.name}#bulk_print_etiketkas error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    flash.now[:error] = "Ошибка при генерации этикеток: #{e.message}"
    render turbo_stream: [
      render_turbo_flash
    ]
  end

  private

  def print_etiketkas_params
    controller_name_singular = controller_name.singularize
    record = instance_variable_get("@#{controller_name_singular}")
    
    # Определяем название записи и путь для редиректа
    case controller_name_singular
    when 'act'
      record_name = 'акте'
      fallback_path = acts_path
      file_identifier = record.number
    when 'incase'
      record_name = 'заявке'
      fallback_path = incases_path
      file_identifier = record.id
    else
      record_name = controller_name_singular
      fallback_path = send("#{controller_name}_path")
      file_identifier = record.respond_to?(:number) ? record.number : record.id
    end
    
    [record, record_name, fallback_path, file_identifier]
  end

  # Получаем ID всех вариантов для массовой печати
  # Проверка наличия этикетки или возможности её сгенерировать делается в методе печати
  def get_valid_variant_ids_for_bulk_print
    case params[:print_type]
    when 'selected'
      # Получаем варианты из выбранных продуктов
      # Используем тот же подход, что и в bulk_delete
      product_ids = params[items]
      
      return [] if product_ids.blank?
      
      # Нормализуем в массив целых чисел (как в bulk_delete)
      product_ids = Array(product_ids).map(&:to_i).reject(&:zero?)
      
      Rails.logger.debug "PrintEtiketkas: normalized product_ids = #{product_ids.inspect}"
      
      return [] if product_ids.empty?
      
      variant_ids = Variant.where(product_id: product_ids).pluck(:id)
      Rails.logger.debug "PrintEtiketkas: found #{variant_ids.count} variants for #{product_ids.count} products"
      variant_ids
    when 'filtered'
      # Получаем варианты из отфильтрованных продуктов
      product_ids = model.ransack(search_params).result(distinct: true).pluck(:id)
      return [] if product_ids.empty?
      
      Variant.where(product_id: product_ids).pluck(:id)
    else
      []
    end
  end

  # Получаем ID всех вариантов из записей (акты, заявки)
  # Проверка наличия этикетки или возможности её сгенерировать делается в методе печати
  def get_valid_variant_ids_from_record(record)
    # Получаем все варианты из позиций записи
    record.items.includes(:variant).map(&:variant_id).compact.uniq
  end

  def items
    "#{controller_name.singularize}_ids".to_sym
  end

  def model
    controller_name.singularize.camelize.constantize
  end

  # Основной метод для печати этикеток по ID вариантов
  def print_etiketkas_from_variant_ids(variant_ids, fallback_path: nil, file_identifier: nil, record_name: nil)
    require 'combine_pdf'
    
    fallback_path ||= send("#{controller_name}_path")
    
    if variant_ids.empty?
      flash[:alert] = record_name ? "В #{record_name} нет позиций с вариантами товаров" : "Нет вариантов для печати"
      redirect_back(fallback_location: fallback_path)
      return
    end
    
    # Загружаем только нужные варианты
    variants = Variant.where(id: variant_ids)
    
    # Генерируем этикетки для всех вариантов
    combined_pdf = CombinePDF.new
    
    variants.each do |variant|
      # Генерируем этикетку, если еще не сгенерирована
      variant.generate_etiketka unless variant.etiketka.attached?
      
      # Добавляем этикетку в PDF, если она есть
      # Если этикетка не сгенерировалась (нет штрихкода или ошибка), просто пропускаем вариант
      if variant.etiketka.attached?
        pdf_data = variant.etiketka.download
        combined_pdf << CombinePDF.parse(pdf_data)
      end
    end
    
    if combined_pdf.pages.empty?
      flash[:alert] = "Не удалось сгенерировать этикетки"
      redirect_back(fallback_location: fallback_path)
      return
    end
    
    # Формируем имя файла
    filename = if file_identifier
      "etiketkas_#{controller_name.singularize}_#{file_identifier}.pdf"
    else
      timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
      "etiketkas_#{controller_name.singularize}_#{timestamp}.pdf"
    end
    
    # Возвращаем объединенный PDF
    send_data combined_pdf.to_pdf, 
              filename: filename, 
              type: 'application/pdf', 
              disposition: 'inline'
  rescue => e
    Rails.logger.error "#{self.class.name}#print_etiketkas error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    flash[:alert] = "Ошибка при генерации этикеток: #{e.message}"
    redirect_back(fallback_location: fallback_path)
  end

end
