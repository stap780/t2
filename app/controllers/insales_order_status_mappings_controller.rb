# frozen_string_literal: true

class InsalesOrderStatusMappingsController < ApplicationController
  before_action :set_mapping, only: %i[edit update destroy]
  include ActionView::RecordIdentifier

  def index
    @mappings = InsalesOrderStatusMapping.includes(:order_status, :insale).order(:id)
  end

  def new
    @mapping = InsalesOrderStatusMapping.new
  end

  def edit; end

  def create
    @mapping = InsalesOrderStatusMapping.new(mapping_params)

    respond_to do |format|
      if @mapping.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "insales_order_status_mappings",
              partial: "insales_order_status_mappings/mapping",
              locals: { mapping: @mapping }
            )
          ]
        end
        format.html { redirect_to insales_order_status_mappings_path, notice: t(".success") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @mapping.update(mapping_params)
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@mapping),
              partial: "insales_order_status_mappings/mapping",
              locals: { mapping: @mapping }
            )
          ]
        end
        format.html { redirect_to insales_order_status_mappings_path, notice: t(".success") }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @mapping.destroy!
    flash.now[:success] = t(".success")
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(dom_id(@mapping)),
          render_turbo_flash
        ]
      end
      format.html { redirect_to insales_order_status_mappings_path, notice: t(".success") }
    end
  end

  private

  def set_mapping
    @mapping = InsalesOrderStatusMapping.find(params[:id])
  end

  def mapping_params
    params.require(:insales_order_status_mapping).permit(
      :insale_id, :insales_status_key, :insales_status_title, :order_status_id
    )
  end
end
