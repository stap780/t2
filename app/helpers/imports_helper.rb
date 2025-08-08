module ImportsHelper
  def import_status_badge(import)
    case import.status
    when 'completed'
      content_tag :span, 'Completed', class: 'px-2 py-1 text-xs font-medium rounded-full text-green-800 bg-green-100'
    when 'processing'
      content_tag :span, 'Processing', class: 'px-2 py-1 text-xs font-medium rounded-full text-blue-800 bg-blue-100'
    when 'failed'
      content_tag :span, 'Failed', class: 'px-2 py-1 text-xs font-medium rounded-full text-red-800 bg-red-100'
    else
      content_tag :span, 'Pending', class: 'px-2 py-1 text-xs font-medium rounded-full text-yellow-800 bg-yellow-100'
    end
  end
  
  def import_icon(import)
    case import.status
    when 'completed'
      'check-circle'
    when 'processing'
      'refresh'
    when 'failed'
      'exclamation-triangle'
    else
      'clock'
    end
  end
end
