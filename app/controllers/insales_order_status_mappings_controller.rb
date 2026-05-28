# frozen_string_literal: true

class InsalesOrderStatusMappingsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_insale
  before_action :set_mapping, only: %i[edit update destroy]
  before_action :set_custom_statuses, only: %i[new edit create update]

  def index
    redirect_to insale_path(@insale, anchor: "insales_statuses")
  end

  def new
    @mapping = @insale.insales_order_status_mappings.build
  end

  def edit; end

  def create
    @mapping = @insale.insales_order_status_mappings.build(mapping_params)

    respond_to do |format|
      if @mapping.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(@insale, :insales_order_status_mappings),
              partial: "insales_order_status_mappings/mapping",
              locals: { mapping: @mapping, insale: @insale }
            )
          ]
        end
        format.html { redirect_to insale_path(@insale, anchor: "insales_statuses"), notice: t(".success") }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            :new_insales_order_status_mapping_form,
            partial: "insales_order_status_mappings/form",
            locals: { mapping: @mapping }
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
              partial: "insales_order_status_mappings/mapping",
              locals: { mapping: @mapping, insale: @insale }
            )
          ]
        end
        format.html { redirect_to insale_path(@insale, anchor: "insales_statuses"), notice: t(".success") }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            dom_id(@mapping, :form),
            partial: "insales_order_status_mappings/form",
            locals: { mapping: @mapping }
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
      format.html { redirect_to insale_path(@insale, anchor: "insales_statuses"), notice: t(".success") }
    end
  end

  private

  def set_insale
    @insale = Insale.find(params[:insale_id])
  end

  def set_mapping
    @mapping = @insale.insales_order_status_mappings.find(params[:id])
  end

  def set_custom_statuses
    @insale.api_init
    @custom_statuses = InsalesApi::CustomStatus.find(:all)
  rescue StandardError => e
    Rails.logger.warn "[InsalesOrderStatusMappings] CustomStatus fetch failed: #{e.message}"
    @custom_statuses = []
  end

  def mapping_params
    params.require(:insales_order_status_mapping).permit(
      :insales_custom_status_permalink, :insales_financial_status, :order_status_id
    )
  end
end
