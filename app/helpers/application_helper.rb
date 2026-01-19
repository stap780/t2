module ApplicationHelper
  def turbo_id_for(obj)
    obj.persisted? ? obj.id : obj.hash
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

  def barcode_icon
    '<svg class="h-4 w-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2 4h2v16H2V4zM6 4h1v16H6V4zM9 4h2v16H9V4zM13 4h1v16h-1V4zM16 4h2v16h-2V4zM20 4h2v16h-2V4z" />
      </svg>'.html_safe
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

  def link_to_history(auditable_type:, auditable_id:, **options)
    return '' if auditable_id.blank?
    
    default_options = {
      class: "inline-flex items-center px-3 py-1 border border-violet-300 shadow-sm text-sm font-medium rounded-md text-violet-700 bg-violet-50 hover:bg-violet-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-violet-500 transition duration-150 ease-in-out",
      data: { turbo_frame: :offcanvas },
      title: 'История изменений'
    }
    
    options = default_options.deep_merge(options)
    
    link_to(
      audited_auditable_audits_path(auditable_type: auditable_type, auditable_id: auditable_id),
      options
    ) do
      '<svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
      </svg>
      <span class="ml-2">История</span>'.html_safe
    end
  end

end
