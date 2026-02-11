require "csv"
require "json"
require "zip"
require "stringio"
require "liquid"
require "caxlsx"

# ExportService inspired by Dizauto's ExportCreator
class ExportService
  def initialize(export)
    @export = export
  end

  def call
    started_at = Time.current
    Rails.logger.info "📤 ExportService: Starting export for Export ##{@export.id} (#{@export.test_mode? ? 'TEST' : 'PRODUCTION'} mode)"
    @export.update!(status: "processing")

    begin
      # Get filtered data based on selected headers
      data = collect_filtered_data

      if data.empty?
        raise "No data available for export. Products may be missing or incomplete."
      end

      # Log data information
      selected_headers_info = @export.file_headers&.any? ? " (#{@export.file_headers.length} selected fields)" : " (all fields)"
      if @export.test_mode?
        Rails.logger.info "📤 ExportService: TEST MODE - Processing #{data.length} records#{selected_headers_info} (limited to #{Export::TEST_LIMIT})"
      else
        Rails.logger.info "📤 ExportService: PRODUCTION MODE - Processing #{data.length} records#{selected_headers_info}"
      end

      # Create export file based on format (like Dizauto)
      result = case @export.format
      when "csv"
        create_csv
      when "xlsx"
        create_xlsx
      when "xml"
        create_xml
      else
        raise "Unsupported export format: #{@export.format}"
      end

      if result
        @export.update!(status: "completed", exported_at: Time.current)
        Rails.logger.info "📤 ExportService: Export completed successfully in #{(Time.current - started_at).round(2)}s"
        [true, @export]
      else
        @export.update!(status: "failed", error_message: "Failed to create export file")
        [false, "Export creation failed"]
      end
    rescue => e
      Rails.logger.error "📤 ExportService ERROR: #{e.message}"
      Rails.logger.error "📤 ExportService ERROR: #{e.backtrace.join("\n")}"

      # Save error message to the export record
      @export.update!(
        status: "failed",
        error_message: "#{e.class.name}: #{e.message}"
      )

      [false, e.message]
    end
  end

  private

  def collect_filtered_data
    # Get source data from export (now from Product model)
    source_data = @export.data
    return [] if source_data.empty?

    # If no specific headers are selected, return all data
    return source_data unless @export.file_headers&.any?

    Rails.logger.info "📤 ExportService: Filtering data to include only selected headers: #{@export.file_headers.join(', ')}"

    # Filter data to include only selected headers
    filtered_data = source_data.map do |record|
      filtered_record = {}
      @export.file_headers.each do |header|
        if record.key?(header)
          filtered_record[header] = record[header]
        else
          Rails.logger.warn "📤 ExportService: Header '#{header}' not found in source data"
          filtered_record[header] = nil
        end
      end
      filtered_record
    end

    Rails.logger.info "📤 ExportService: Filtered #{filtered_data.length} records to #{@export.file_headers.length} selected fields"
    filtered_data
  end

  def create_csv
    # Сначала получаем все данные и разворачиваем их
    source_data = @export.data
    return false if source_data.empty?

    # Преобразуем данные в плоский формат для CSV
    flattened_data = flatten_data_for_csv(source_data)

    # Теперь фильтруем по выбранным заголовкам (если они выбраны)
    if @export.file_headers&.any?
      Rails.logger.info "📤 ExportService: Filtering flattened data to include only selected headers: #{@export.file_headers.join(', ')}"
      flattened_data = flattened_data.map do |record|
        filtered_record = {}
        @export.file_headers.each do |header|
          filtered_record[header] = record[header] if record.key?(header)
        end
        filtered_record
      end
      # Используем выбранные заголовки для CSV
      headers = @export.file_headers
    else
      # Используем все доступные заголовки из данных
      headers = flattened_data.first.keys
    end

    csv_content = CSV.generate do |csv|
      csv << headers

      # Add data rows
      flattened_data.each do |record|
        csv << headers.map { |header| record[header] }
      end
    end

    attach_file(csv_content, "csv", "text/csv")
  end

  def create_xlsx
    # Сначала получаем все данные и разворачиваем их
    source_data = @export.data
    return false if source_data.empty?

    # Преобразуем данные в плоский формат для XLSX
    flattened_data = flatten_data_for_csv(source_data)

    # Теперь фильтруем по выбранным заголовкам (если они выбраны)
    if @export.file_headers&.any?
      Rails.logger.info "📤 ExportService: Filtering flattened data to include only selected headers: #{@export.file_headers.join(', ')}"
      flattened_data = flattened_data.map do |record|
        filtered_record = {}
        @export.file_headers.each do |header|
          filtered_record[header] = record[header] if record.key?(header)
        end
        filtered_record
      end
      # Используем выбранные заголовки для XLSX
      headers = @export.file_headers
    else
      # Используем все доступные заголовки из данных
      headers = flattened_data.first.keys
    end

    # Create XLSX using Axlsx
    p = Axlsx::Package.new
    wb = p.workbook

    wb.add_worksheet(name: "Sheet 1") do |sheet|
      # Add headers
      sheet.add_row headers

      # Add data rows
      flattened_data.each do |record|
        sheet.add_row headers.map { |header| record[header] }
      end
    end

    # Generate XLSX content
    stream = p.to_stream
    xlsx_content = stream.read

    attach_file(xlsx_content, "xlsx", "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")
  end

  def create_xml
    unless @export.layout_template.present? && @export.item_template.present?
      return false, "XML templates are required"
    end

    # Prepare data for items
    products = @export.data

    # Parse templates
    item_template   = Liquid::Template.parse(@export.item_template)
    layout_template = Liquid::Template.parse(@export.layout_template)

    # Build items XML in Ruby loop (one render per product)
    items_xml = +""
    products.each do |product_hash|
      items_xml << item_template.render("product" => product_hash)
      items_xml << "\n"
    end

    # Render final XML using layout (receives export drop and prebuilt items_xml)
    export_drop = Drop::Export.new(@export)
    xml_content = layout_template.render(
      "export"    => export_drop,
      "items_xml" => items_xml
    )

    attach_file(xml_content, "xml", "application/xml")
  end

  def flatten_data_for_csv(data)
    Rails.logger.debug "📤 ExportService: Flattening #{data.length} products for CSV"
    
    data.map do |product_hash|
      flattened = {}
      
      # Копируем базовые поля Product
      product_hash.each do |key, value|
        next if %w[variants features images images_zap images_second images_thumb].include?(key)
        flattened[key] = value
      end
      
      # Разворачиваем variants
      if product_hash['variants'].present? && product_hash['variants'].is_a?(Array) && product_hash['variants'].any?
        product_hash['variants'].each_with_index do |variant, index|
          if variant.is_a?(Hash)
            variant.each do |vk, vv|
              next if %w[id product_id created_at updated_at].include?(vk.to_s)
              flattened["variant_#{index + 1}_#{vk}"] = vv
            end
          end
        end
      end
      
      # Разворачиваем features
      # features_to_h возвращает хеш с ключами из property.title (могут быть на русском)
      features_data = product_hash['features'] || product_hash[:features]
      if features_data.present?
        # Преобразуем в обычный хеш, если это ActiveSupport::HashWithIndifferentAccess
        features_hash = features_data.is_a?(Hash) ? features_data : {}
        if features_hash.any?
          Rails.logger.debug "📤 ExportService: Product #{product_hash['id']} has features: #{features_hash.keys.join(', ')}"
          features_hash.each do |property, characteristic|
            # Используем to_s для гарантии строкового ключа
            # property может быть на русском (например, "Марка" вместо "Brand")
            property_key = property.to_s
            characteristic_value = characteristic.to_s
            # Используем точное название свойства как ключ
            flattened["feature_#{property_key}"] = characteristic_value
            Rails.logger.debug "📤 ExportService: Added feature_#{property_key} = #{characteristic_value}"
          end
        else
          Rails.logger.debug "📤 ExportService: Product #{product_hash['id']} has empty features hash"
        end
      else
        Rails.logger.debug "📤 ExportService: Product #{product_hash['id']} has no features data"
      end
      
      # Объединяем images через разделитель (запятая)
      if product_hash['images'].present?
        flattened['images'] = Array(product_hash['images']).compact.join(',')
      end
      
      # Также добавляем другие варианты изображений если они есть
      if product_hash['images_zap'].present?
        flattened['images_zap'] = Array(product_hash['images_zap']).compact.join(',')
      end
      
      if product_hash['images_second'].present?
        flattened['images_second'] = Array(product_hash['images_second']).compact.join(',')
      end
      
      if product_hash['images_thumb'].present?
        flattened['images_thumb'] = Array(product_hash['images_thumb']).compact.join(',')
      end
      
      Rails.logger.debug "📤 ExportService: Flattened product #{product_hash['id']}: #{flattened.keys.join(', ')}"
      flattened
    end
  end

  def attach_file(content, format, content_type)
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    filename = "export_#{@export.id}_#{timestamp}.#{format}"

    ActiveStorage::Attachment.where(record_type: 'Export', record_id: @export.id, name: 'export_file').each(&:purge)
    
    @export.export_file.attach(
      io: StringIO.new(content),
      filename: filename,
      content_type: content_type
    )

    true
  end
end
