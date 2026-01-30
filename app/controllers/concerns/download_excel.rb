module DownloadExcel
  extend ActiveSupport::Concern

  def download
    if params[:download_type] == 'selected' && !params[items].present?
      flash.now[:error] = 'Выберите позиции'
      render turbo_stream: [
        render_turbo_flash
      ]
    else
      # puts "controller_name => #{controller_name}"
      # Использовать существующий ExportService или создать новый
      CreateZipXlsxJob.perform_later(excel_collection_ids, {
        model: controller_name, 
        download_kind: params[:download_kind].presence ? params[:download_kind] : nil,
        current_user_id: Current.user&.id
      })

      render turbo_stream: [
        turbo_stream.update('offcanvas',template: 'shared/download'),
        turbo_stream.set_unchecked(targets: '.checkboxes')
      ]
    end
  end

  protected

  def items
    "#{controller_name.singularize}_ids".to_sym
  end

  def model
    controller_name.singularize.camelize.constantize
  end

  def model_product?
    model == 'Product'
  end

  def excel_collection_ids
    case params[:download_type]
    when 'selected'
      collection_ids = model.include_images.where(id: params[items]).pluck(:id) if model_product?
      collection_ids = model.where(id: params[items]).pluck(:id) unless model_product?
    when 'filtered'
      if controller_name == 'incases'
        base_relation = Incase.includes(:company, :strah)
        search_params_hash = search_params || {}
        processed_params = process_multiple_unumber_search(search_params_hash.dup)
        searching_by_barcode = processed_params.keys.any? { |key| key.to_s.include?('items_barcode') }
        base_relation = base_relation.left_joins(items: :variant) if searching_by_barcode
        collection_ids = base_relation.ransack(processed_params).result(distinct: true).pluck(:id)
      elsif model_product?
        collection_ids = model.include_images.ransack(search_params).result(distinct: true).pluck(:id)
      else
        collection_ids = model.all.ransack(search_params).result(distinct: true).pluck(:id)
      end
    when 'all'
      collection_ids = model.include_images.pluck(:id) if model_product?
      collection_ids = model.all.pluck(:id) unless model_product?
    end
    collection_ids
  end

end

