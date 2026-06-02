# frozen_string_literal: true

class ExportColumnsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_export
  before_action :set_export_column, only: :destroy

  def new
    @export_column = @export.export_columns.build
    respond_to(&:turbo_stream)
  end

  def destroy
    @export_column.destroy if @export_column.persisted?
    respond_to do |format|
      format.turbo_stream do
        flash.now[:success] = t(".success")
        render turbo_stream: [
          turbo_stream.remove(dom_id(@export_column)),
          render_turbo_flash
        ]
      end
      format.html { redirect_to edit_export_path(@export), notice: t(".success") }
    end
  end

  private

  def set_export
    @export = Export.find(params[:export_id])
  end

  def set_export_column
    @export_column = @export.export_columns.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @export_column = @export.export_columns.build(id: params[:id])
  end
end
