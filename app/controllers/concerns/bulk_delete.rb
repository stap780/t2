module BulkDelete
  extend ActiveSupport::Concern

  def bulk_delete
    if params[:delete_type] == 'selected' && !params[items].present?
      flash.now[:error] = 'Выберите позиции'
    else
      BulkDeleteJob.perform_later(delete_collection_ids, {
        model: model.to_s, 
        current_user_id: Current.user&.id
      })
      flash.now[:success] = 'Запустили удаление'
    end
    render turbo_stream: [
      render_turbo_flash
    ]
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

  def delete_collection_ids
    case params[:delete_type]
    when 'selected'
      collection_ids = model.include_images.where(id: params[items]).pluck(:id) if model_product?
      collection_ids = model.where(id: params[items]).pluck(:id) unless model_product?
    when 'filtered'
      collection_ids = model.include_images.ransack(search_params).result(distinct: true).pluck(:id) if model_product?
      collection_ids = model.all.ransack(search_params).result(distinct: true).pluck(:id) unless model_product?
    when 'all'
      collection_ids = model.include_images.pluck(:id) if model_product?
      collection_ids = model.all.pluck(:id) unless model_product?
    end
    collection_ids
  end

  def search_params
    params[:q] || {}
  end
end

