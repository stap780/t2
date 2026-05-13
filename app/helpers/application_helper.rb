module ApplicationHelper
  def turbo_id_for(obj)
    obj.persisted? ? obj.id : obj.hash
  end

  # Заголовок с иконкой-подсказкой (label + ℹ с CSS tooltip при наведении)
  def header_with_info(label, tooltip:, align: :left)
    align_classes = { right: "text-right justify-end", center: "text-center justify-center", left: "text-left justify-start" }
    content_tag(:div, class: "whitespace-nowrap flex items-center gap-1 #{align_classes[align]}") do
      info_span = content_tag(:span, class: "relative inline-flex group text-gray-400 shrink-0") do
        svg_icon = tag.svg(class: "w-3.5 h-3.5", fill: "none", stroke: "currentColor", viewBox: "0 0 24 24") do
          tag.path(stroke_linecap: "round", stroke_linejoin: "round", stroke_width: "2", d: "M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z")
        end
        tooltip_el = content_tag(:span, tooltip,
          class: "absolute left-1/2 -translate-x-1/2 top-full mt-1 px-2 py-1 text-xs text-white bg-gray-800 rounded-md shadow-lg whitespace-normal max-w-[220px] z-[9999] opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-opacity duration-150 pointer-events-none normal-case")
        safe_join([svg_icon, tooltip_el])
      end
      safe_join([label, info_span])
    end
  end

  def delete_icon
    '<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
      </svg>'.html_safe
  end

  def varbind_icon
    '<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13.828 10.172a4 4 0 00-5.656 0l-4 4a4 4 0 105.656 5.656l1.102-1.101m-.758-4.899a4 4 0 005.656 0l4-4a4 4 0 00-5.656-5.656l-1.1 1.1" />
      </svg>'.html_safe
  end

  def sync_icon
    '<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-green-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
      </svg>'.html_safe
  end

  def barcode_icon
    '<svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <rect x="2" y="6" width="2" height="12" fill="currentColor"/>
            <rect x="6" y="6" width="1" height="12" fill="currentColor"/>
            <rect x="9" y="6" width="2" height="12" fill="currentColor"/>
            <rect x="13" y="6" width="1" height="12" fill="currentColor"/>
            <rect x="16" y="6" width="2" height="12" fill="currentColor"/>
            <rect x="20" y="6" width="1" height="12" fill="currentColor"/>
          </svg>'.html_safe
  end

  def dropdown_icon
    '<svg class="w-4 h-4 ml-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
    </svg>'.html_safe
  end

  def generate_barcode_icon
    '<svg class="w-4 h-4 text-green-700" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <rect x="2" y="6" width="2" height="12" fill="currentColor"/>
      <rect x="6" y="6" width="1" height="12" fill="currentColor"/>
      <rect x="9" y="6" width="2" height="12" fill="currentColor"/>
      <rect x="13" y="6" width="1" height="12" fill="currentColor"/>
      <rect x="16" y="6" width="2" height="12" fill="currentColor"/>
      <rect x="20" y="6" width="1" height="12" fill="currentColor"/>
      <g>
        <path d="M7 4v-1a2 2 0 0 1 2-2h6a2 2 0 0 1 2 2v1" stroke="currentColor" stroke-width="1" fill="none"/>
        <rect x="10" y="1.5" width="4" height="3" rx="1" fill="currentColor" opacity="0.15"/>
      </g>
      <g>
        <path d="M12 9v3m0 0l2-2m-2 2l-2-2" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/>
      </g>
    </svg>'.html_safe
  end

  def bulk_features_icon
    '<svg class="w-4 h-4 mr-1 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h7" />
    </svg>'.html_safe
  end

  def filter_icon
    '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 4a1 1 0 011-1h16a1 1 0 011 1v2a2 2 0 01-.553 1.382l-6.553 7.276V19a1 1 0 01-1.447.894l-2-1A1 1 0 019 18v-5.342L2.553 7.382A2 2 0 012 6V4z"/>
    </svg>'.html_safe
  end

  def link_to_filter(path, **options)
    if options[:class]
      options[:class]
    else
      options[:class] = "inline-flex items-center px-2 py-1 bg-blue-600 text-white rounded-md hover:bg-blue-700"
    end
    options[:title] ||= t('products.index.filter')
    button_text = options[:text]
    link_to path, options do
      filter_icon + content_tag(:span, button_text, class: "ml-1")
    end
  end

  def link_to_generate_barcode(path, **options)
    if options[:class]
      options[:class]
    elsif !options[:class]
      options[:class] = "p-2 rounded-md bg-gray-50 hover:bg-gray-100 flex items-center justify-center h-8"
    end
    options[:title] ||= t('generate_barcode')
    link_to path, options do
      generate_barcode_icon
    end
  end

  def link_to_print_barcode(path, **options)
    if options[:class]
      options[:class]
    elsif !options[:class]
      options[:class] = "p-2 rounded-md bg-gray-50 hover:bg-gray-100 flex items-center justify-center h-8"
    end
    options[:title] ||= t('print_barcode')
    options[:target] ||= "_blank"
    link_to path, options do
      barcode_icon
    end
  end

  def link_to_varbind(path, **options)
    if options[:class]
      options[:class]
    elsif !options[:class]
      options[:class] = "p-2 rounded-md bg-blue-50 hover:bg-blue-100 flex items-center justify-center h-8"
    end
    link_to path, options do
      varbind_icon
    end
  end

  def edit_icon
    '<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-violet-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
    </svg>'.html_safe
  end

  def show_icon
    '<svg xmlns="http://www.w3.org/2000/svg" class="h-4 w-4 text-blue-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
        </svg>'.html_safe
  end

  def link_to_show(path, **options)
    if options[:class]
      options[:class]
    elsif !options[:class]
      options[:class] = "p-2 rounded-md bg-blue-100 hover:bg-blue-200 flex items-center justify-center h-8"
    end
    options[:title] ||= t('show')
    link_to path, options do
      show_icon
    end
  end

  def link_to_edit(path, **options)
    if options[:class]
      options[:class]
    elsif !options[:class]
      options[:class] = "p-2 rounded-md bg-violet-100 hover:bg-violet-200 flex items-center justify-center h-8"
    end
    options[:title] ||= t('edit')

    # Правильно мержим data атрибуты, если они переданы
    if options[:data].present?
      # data уже есть, ничего не делаем - он будет передан в link_to
    else
      options[:data] = {}
    end
    
    link_to path, options do
      edit_icon
    end
  end

  def link_to_delete(path, **options)
    if options[:class]
      options[:class]
    else
      options[:class] = "flex items-center justify-center px-2 py-1 border border-transparent text-xs font-medium rounded text-red-700 bg-red-100 hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition duration-150 ease-in-out h-8"
    end
    options[:title] ||= t('delete')
    options[:data] ||= {}
    
    link_to path, options do
      delete_icon
    end
  end

  def link_to_back(path, **options)
    options[:class] ||= "text-gray-600 hover:text-gray-900 flex items-center gap-1 text-sm"
    link_to path, options do
      raw('<span class="mr-1">&#8592;</span>') + t("common.back")
    end
  end

  def link_to_sync(path, **options)
    if options[:class]
      options[:class]
    elsif !options[:class]
      options[:class] = "p-2 rounded-md bg-green-100 hover:bg-green-200 flex items-center justify-center h-8"
    end
    options[:title] ||= t('sync')
    link_to path, options do
      sync_icon
    end
  end

  def prepend_flash
    turbo_stream.prepend "our_flash", partial: "shared/flash"
  end
  
  # Change the default link renderer for will_paginate
  def will_paginate(collection_or_options = nil, options = {})
    if collection_or_options.is_a? Hash
      options, collection_or_options = collection_or_options, nil
    end
    unless options[:renderer]
      options = options.merge renderer: WillPaginate::ActionView::CustomRenderer
    end
    super *[collection_or_options, options].compact
  end

  def highlight(text, phrase)
    return text if phrase.blank?
    text.to_s.gsub(/(#{Regexp.escape(phrase)})/i, '<mark class="bg-yellow-200">\1</mark>').html_safe
  end

  def history_value(attribute, value, auditable_type: nil)
    return '-' if value.blank?
    
    # Специальная обработка для определенных типов атрибутов
    case attribute.to_s
    when 'created_at', 'updated_at', 'deleted_at'
      value.is_a?(Time) || value.is_a?(Date) ? value.strftime('%d.%m.%Y %H:%M') : value
    when 'description'
      # Для description обрезаем длинный текст и показываем первые 100 символов
      text = value.to_s
      text.length > 100 ? "#{text[0..100]}..." : text
    when 'status'
      # Перевод статусов для Product
      if auditable_type == 'Product'
        t("products.form.status.#{value}", default: value)
      else
        value
      end
    when 'tip'
      # Перевод типов для Product
      if auditable_type == 'Product'
        t("products.form.tip.#{value}", default: value)
      else
        value
      end
    when 'state'
      value
    else
      # Обработка атрибутов с _id суффиксом (связанные объекты)
      if attribute.to_s.end_with?('_id')
        begin
          # Пытаемся преобразовать значение в число
          id_value = value.to_i
          return value if id_value.zero? && value.to_s != '0'
          
          association_name = attribute.to_s.gsub(/_id$/, '')
          model_class = case association_name
          when 'variant'
            Variant
          when 'item_status'
            ItemStatus
          when 'company', 'strah'
            Company
          when 'incase'
            Incase
          when 'incase_status'
            IncaseStatus
          when 'incase_tip'
            IncaseTip
          when 'okrug'
            Okrug
          when 'driver'
            User
          when 'product'
            Product
          when 'characteristic'
            Characteristic
          when 'property'
            Property
          else
            nil
          end
          
          if model_class
            associated_object = model_class.find_by(id: id_value)
            if associated_object
              # Для Variant используем full_title, для остальных - title или short_title
              case association_name
              when 'variant'
                associated_object.respond_to?(:full_title) ? associated_object.full_title : associated_object.id.to_s
              when 'company', 'strah'
                associated_object.respond_to?(:short_title) ? associated_object.short_title : (associated_object.respond_to?(:title) ? associated_object.title : associated_object.id.to_s)
              when 'item_status', 'incase_status', 'incase_tip', 'okrug'
                associated_object.respond_to?(:title) ? associated_object.title : associated_object.id.to_s
              when 'driver'
                associated_object.respond_to?(:email_address) ? associated_object.email_address : associated_object.id.to_s
              when 'product'
                associated_object.respond_to?(:title) ? associated_object.title : associated_object.id.to_s
              when 'characteristic', 'property'
                associated_object.respond_to?(:title) ? associated_object.title : associated_object.id.to_s
              else
                associated_object.respond_to?(:title) ? associated_object.title : (associated_object.respond_to?(:name) ? associated_object.name : associated_object.id.to_s)
              end
            else
              # Объект не найден (возможно, был удален)
              "#{id_value} (deleted)"
            end
          else
            value
          end
        rescue => e
          Rails.logger.error "history_value error for #{attribute}: #{e.message}"
          value
        end
      else
        value
      end
    end
  end

  def history_icon
    '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
    </svg>'.html_safe
  end

  def link_to_history(auditable_type:, auditable_id:, **options)
    return '' if auditable_id.blank?
    
    default_options = {
      class: "inline-flex items-center px-3 py-1 border border-violet-300 shadow-sm text-sm font-medium rounded-md text-violet-700 bg-violet-50 hover:bg-violet-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-violet-500 transition duration-150 ease-in-out",
      data: { turbo_frame: :offcanvas, turbo_prefetch: false },
      title: 'История изменений'
    }
    
    options = default_options.deep_merge(options)
    
    link_to(
      audited_auditable_audits_path(auditable_type: auditable_type, auditable_id: auditable_id),
      options
    ) do
      history_icon
      # '<span class="ml-2">История</span>'.html_safe
    end
  end

end
