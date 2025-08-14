class ExportsController < ApplicationController
  before_action :set_export, only: [:edit, :update, :run, :destroy, :download]

  def index
    # Show all exports from current user
    @exports = Current.user.exports.recent
  end

  def new
    @export = Current.user.exports.build
  end

  def create
    # Create export for the current user - only save setup, don't run
    @export = Current.user.exports.build(export_params)

    if @export.save
      redirect_to exports_path, notice: "Export setup saved successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Update export setup - don't run automatically
    if @export.update(export_params)
      redirect_to exports_path, notice: "Export setup updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def run
    # Run the export job
    Rails.logger.info "🎯 Controller: Queuing ExportJob for Export ##{@export.id} at #{Time.current}"
    ExportJob.perform_later(@export)
    Rails.logger.info "🎯 Controller: ExportJob queued successfully for Export ##{@export.id}"

    respond_to do |format|
      format.turbo_stream { 
        render turbo_stream: turbo_stream.replace(@export, partial: "exports/export", locals: { export: @export })
      }
      format.html { redirect_to exports_path, notice: "Export started successfully." }
    end
  end

  def download
    # Check if export is completed and file exists
    unless @export.completed?
      redirect_to exports_path, alert: 'Export is not completed yet.'
      return
    end

    unless @export.export_file.attached?
      redirect_to exports_path, alert: 'File not found.'
      return
    end

    # Send the file using Active Storage blob (Rails 8 pattern)
    send_data @export.export_file.download,
              filename: @export.export_file.filename.to_s,
              type: @export.export_file.content_type,
              disposition: 'attachment'
  end
  
  def destroy
    @export.destroy
    redirect_to exports_path, notice: "Export deleted successfully."
  end
  
  private
  
  def set_export
    @export = Current.user.exports.find(params[:id])
  end

  # Use Rails 8 strong parameters pattern
  def export_params
    params.expect(export: [:name, :format, :template, :test, file_headers: []])
  end
end
