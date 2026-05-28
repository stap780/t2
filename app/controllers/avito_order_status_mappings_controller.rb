# frozen_string_literal: true

class AvitoOrderStatusMappingsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_avito
  before_action :set_mapping, only: %i[edit update destroy]

  def index
    redirect_to avito_path(@avito, anchor: "avitos_statuses")
  end

  def new
    @mapping = @avito.avito_order_status_mappings.build
  end

  def edit; end

  def create
    @mapping = @avito.avito_order_status_mappings.build(mapping_params)

    respond_to do |format|
      if @mapping.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(@avito, :avito_order_status_mappings),
              partial: "avito_order_status_mappings/mapping",
              locals: { mapping: @mapping, avito: @avito }
            )
          ]
        end
        format.html { redirect_to avito_path(@avito, anchor: "avitos_statuses"), notice: t(".success") }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            :new_avito_order_status_mapping_form,
            partial: "avito_order_status_mappings/form",
            locals: { mapping: @mapping, avito: @avito }
          ), status: :unprocessable_entity
        end
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
              partial: "avito_order_status_mappings/mapping",
              locals: { mapping: @mapping, avito: @avito }
            )
          ]
        end
        format.html { redirect_to avito_path(@avito, anchor: "avitos_statuses"), notice: t(".success") }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@mapping, :form),
            partial: "avito_order_status_mappings/form",
            locals: { mapping: @mapping, avito: @avito }
          ), status: :unprocessable_entity
        end
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
      format.html { redirect_to avito_path(@avito, anchor: "avitos_statuses"), notice: t(".success") }
    end
  end

  private

  def set_avito
    @avito = Avito.find(params[:avito_id])
  end

  def set_mapping
    @mapping = @avito.avito_order_status_mappings.find(params[:id])
  end

  def mapping_params
    params.require(:avito_order_status_mapping).permit(:order_status_id, :avito_status)
  end
end
