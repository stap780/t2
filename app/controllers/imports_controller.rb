class ImportsController < ApplicationController

  before_action :set_import, only: [:show, :destroy, :download]

  def index
    @search = Import.ransack(params[:q])
    @search.sorts = "id desc" if @search.sorts.empty?
    @imports = @search.result(distinct: true).paginate(page: params[:page], per_page: 50)
    @recent_import = @imports.first
  end

  def show; end

  def download
    # Check if import is completed and file exists
    unless @import.completed?
      redirect_to imports_path, alert: 'Import is not completed yet.'
      return
    end

    unless @import.zip_file.attached?
      redirect_to imports_path, alert: 'File not found.'
      return
    end

    # Send the file using Active Storage blob
    # Works with data-turbo="false" to bypass Turbo navigation
    send_data @import.zip_file.download,
              filename: @import.zip_file.filename.to_s,
              type: @import.zip_file.content_type,
              disposition: 'attachment'
  end

  def create
    # Create import for the current user
    @import = Current.user.imports.build(import_params)

    if @import.save
      # Run import service in background
      Rails.logger.info "🎯 Controller: Queuing ImportJob for Import ##{@import.id} at #{Time.current}"
      ImportJob.perform_later(@import)
      Rails.logger.info "🎯 Controller: ImportJob queued successfully for Import ##{@import.id}"

      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.prepend(:imports, @import) }
        format.html { redirect_to imports_path, notice: "Import started successfully." }
      end
    else
      respond_to do |format|
        format.turbo_stream { render turbo_stream: turbo_stream.replace(:import_form, partial: "form", locals: { import: @import }) }
        format.html { redirect_to imports_path, alert: "Failed to start import." }
      end
    end
  end
  
  def destroy
    @import.destroy

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(@import) }
      format.html { redirect_to imports_path, notice: "Import deleted successfully." }
    end
  end
  
  private
  
  def set_import
    @import = Import.find(params[:id])
  end

  def import_params
    params.fetch(:import, {}).permit(:name)
  end
end
