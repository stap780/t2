module BulkStatus
  extend ActiveSupport::Concern

  def bulk_status
    model_name = controller_name.singularize
    ids_param = "#{model_name}_ids".to_sym
    status_param = "#{model_name}_status_id".to_sym
    
    if params[ids_param].present? && params[status_param].present?
      model = model_name.camelize.constantize
      records = model.where(id: params[ids_param])
      status_field = "#{model_name}_status_id"
      
      updated_count = records.update_all(status_field => params[status_param])
      
      flash.now[:success] = t('.success', count: updated_count)
      
      respond_to do |format|
        format.turbo_stream do
          # Reload records to get updated statuses
          updated_records = model.where(id: params[ids_param]).includes(:company, :strah, :incase_status, :incase_tip, :items)
          streams = [render_turbo_flash]
          
          updated_records.each do |record|
            streams << turbo_stream.replace(
              ActionView::RecordIdentifier.dom_id(record),
              partial: "#{model_name.pluralize}/#{model_name}",
              locals: { model_name.to_sym => record }
            )
          end
          
          render turbo_stream: streams
        end
        format.html { redirect_to polymorphic_path(model_name.pluralize.to_sym), notice: t('.success', count: updated_count) }
      end
    else
      flash.now[:error] = 'Выберите записи и статус'
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [render_turbo_flash]
        end
        format.html { redirect_to polymorphic_path(model_name.pluralize.to_sym), alert: 'Выберите записи и статус' }
      end
    end
  end
end

