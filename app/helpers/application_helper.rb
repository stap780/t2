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
      options[:class] = "p-2 rounded-md bg-blue-50 hover:bg-blue-100 flex items-center justify-center"
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
      options[:class] = "p-2 rounded-md bg-violet-100 hover:bg-violet-200 flex items-center justify-center"
    end
    options[:title] ||= t('edit')
    
    link_to path, options do
      edit_icon
    end
  end

  def link_to_delete(path, **options)
    if options[:class]
      options[:class]
    else
      options[:class] = "flex items-center justify-center px-2 py-1 border border-transparent text-xs font-medium rounded text-red-700 bg-red-100 hover:bg-red-200 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500 transition duration-150 ease-in-out"
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


end
