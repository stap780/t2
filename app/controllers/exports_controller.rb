class ExportsController < ApplicationController
  # Allow public access to the stable file URL for external services
  allow_unauthenticated_access only: [:file]

  before_action :set_export, only: [:edit, :update, :run, :destroy, :download, :cancel]
  before_action :set_export_public, only: [:file]

  def index
    # Show all exports from current user
    # @exports = Current.user.exports.recent
    @exports = Export.recent.includes(:user)
  end

  def new
    @export = Current.user.exports.build
  end

  def create
    # Create export for the current user - only save setup, don't run
    @export = Current.user.exports.build(export_params)

    if @export.save
      redirect_to exports_path, notice: t(".success")
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    # Update export setup - don't run automatically
    if @export.update(export_params)
      redirect_to exports_path, notice: t(".success")
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def run
    # Always run immediately, regardless of any scheduled time
    Rails.logger.info "🎯 Controller: Queuing immediate ExportJob for Export ##{@export.id} at #{Time.current}"
    ExportJob.perform_later(@export)
    notice = t(".success")

    respond_to do |format|
      format.turbo_stream { 
        render turbo_stream: turbo_stream.replace(@export, partial: "exports/export", locals: { export: @export })
      }
      format.html { redirect_to exports_path, notice: notice }
    end
  end

  def cancel
    @export.cancel_pending_job
    @export.update(status: "pending")
    notice = t(".success")
    respond_to do |format|
      format.turbo_stream { 
        render turbo_stream: turbo_stream.replace(@export, partial: "exports/export", locals: { export: @export })
      }
      format.html { redirect_to exports_path, notice: notice }
    end
  end

  def download
    # Check if export is completed and file exists
    unless @export.completed?
      redirect_to exports_path, alert: t(".not_completed")
      return
    end

    unless @export.export_file.attached?
      redirect_to exports_path, alert: t(".file_not_found")
      return
    end

    # Send the file using Active Storage blob (Rails 8 pattern)
    send_data @export.export_file.download,
              filename: @export.export_file.filename.to_s,
              type: @export.export_file.content_type,
              disposition: "attachment"
  end

  # Stable URL for browsers/external services: serves inline with a consistent filename
  def file
    unless @export.completed? && @export.export_file.attached?
      head :not_found and return
    end

    # Build a stable, deterministic filename, e.g., export-<id>.<ext>
    filename_obj = @export.export_file.filename
    ext = filename_obj.extension.present? ? ".#{filename_obj.extension}" : ""
    stable_name = "export-#{@export.id}#{ext}"

    send_data @export.export_file.download,
              filename: stable_name,
              type: @export.export_file.content_type,
              disposition: 'inline'
  end

  def destroy
    @export.destroy
    redirect_to exports_path, notice: t(".success")
  end

  def xml_avito_example; end

  private
  
  def set_export
    # @export = Current.user.exports.find(params[:id])
    @export = Export.find(params[:id])
  end

  # Public finder for unauthenticated file access
  def set_export_public
    @export = Export.find(params[:id])
  end

  # Use Rails 8 strong parameters pattern
  def export_params
    params.expect(export: [:name, :format, :template, :test, :time, file_headers: []])
  end
end
