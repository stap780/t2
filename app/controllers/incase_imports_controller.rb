class IncaseImportsController < ApplicationController
  include ActionView::RecordIdentifier
  
  before_action :set_incase_import, only: %i[show destroy]
  
  def index
    @search = IncaseImport.ransack(params[:q])
    @search.sorts = 'created_at desc' if @search.sorts.empty?
    @incase_imports = @search.result(distinct: true).includes(:user).paginate(page: params[:page], per_page: 50)
  end
  
  def show
  end
  
  def new
    @incase_import = IncaseImport.new
  end
  
  def create
    @incase_import = IncaseImport.new(incase_import_params)
    @incase_import.user = Current.user
    
    respond_to do |format|
      if @incase_import.save
        IncaseImportJob.perform_later(@incase_import.id)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "incase_imports",
              partial: "incase_imports/incase_import",
              locals: { incase_import: @incase_import }
            )
          ]
        end
        format.html { redirect_to incase_imports_path, notice: t('.success') }
        format.json { render :show, status: :created, location: @incase_import }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @incase_import.errors, status: :unprocessable_entity }
      end
    end
  end
  
  def destroy
    @incase_import.destroy
    
    respond_to do |format|
      format.html { redirect_to incase_imports_path, notice: t('.success') }
      format.turbo_stream do
        flash.now[:success] = t('.success')
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.remove(dom_id(@incase_import))
        ]
      end
    end
  end
  
  private
  
  def set_incase_import
    @incase_import = IncaseImport.find(params[:id])
  end
  
  def incase_import_params
    params.require(:incase_import).permit(:file)
  end
end

