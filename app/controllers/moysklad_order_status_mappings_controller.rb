# frozen_string_literal: true

class MoyskladOrderStatusMappingsController < ApplicationController
  before_action :set_mapping, only: %i[edit update destroy]
  include ActionView::RecordIdentifier

  def index
    @mappings = MoyskladOrderStatusMapping.includes(:order_status).order(:id)
  end

  def new
    @mapping = MoyskladOrderStatusMapping.new
  end

  def edit; end

  def create
    @mapping = MoyskladOrderStatusMapping.new(mapping_params)

    respond_to do |format|
      if @mapping.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "moysklad_order_status_mappings",
              partial: "moysklad_order_status_mappings/mapping",
              locals: { mapping: @mapping }
            )
          ]
        end
        format.html { redirect_to moysklad_order_status_mappings_path, notice: t(".success") }
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
              partial: "moysklad_order_status_mappings/mapping",
              locals: { mapping: @mapping }
            )
          ]
        end
        format.html { redirect_to moysklad_order_status_mappings_path, notice: t(".success") }
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
      format.html { redirect_to moysklad_order_status_mappings_path, notice: t(".success") }
    end
  end

  private

  def set_mapping
    @mapping = MoyskladOrderStatusMapping.find(params[:id])
  end

  def mapping_params
    params.require(:moysklad_order_status_mapping).permit(
      :moysklad_state_href, :moysklad_state_name, :order_status_id
    )
  end
end
