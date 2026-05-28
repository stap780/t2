# frozen_string_literal: true

class MoyskladOrderStatusMappingsController < ApplicationController
  before_action :set_mapping, only: %i[edit update destroy]
  before_action :load_ms_states, only: %i[new edit create update]
  include ActionView::RecordIdentifier

  def index
    if (moysklad = Moysklad.order(:id).first)
      redirect_to moysklad_path(moysklad, anchor: "moysklads_statuses")
      return
    end

    @mappings = MoyskladOrderStatusMapping.includes(:order_status).order(:id)
  end

  def new
    @mapping = MoyskladOrderStatusMapping.new
  end

  def edit; end

  def create
    @mapping = MoyskladOrderStatusMapping.new(mapping_params)
    apply_state_name(@mapping)

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
        format.html { redirect_to moysklad_settings_path, notice: t(".success") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    @mapping.assign_attributes(mapping_params)
    apply_state_name(@mapping)

    respond_to do |format|
      if @mapping.save
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
        format.html { redirect_to moysklad_settings_path, notice: t(".success") }
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
      format.html { redirect_to moysklad_settings_path, notice: t(".success") }
    end
  end

  private

  def set_mapping
    @mapping = MoyskladOrderStatusMapping.find(params[:id])
  end

  def load_ms_states
    moysklad = Moysklad.order(:id).first
    return unless moysklad&.api_work?[0]

    @ms_states = MoyskladApi::ReferenceData.customerorder_states(moysklad)
  end

  def moysklad_settings_path
    moysklad = Moysklad.order(:id).first
    moysklad ? moysklad_path(moysklad, anchor: "moysklads_statuses") : moysklad_order_status_mappings_path
  end
  helper_method :moysklad_settings_path

  def apply_state_name(mapping)
    return if @ms_states.blank? || mapping.moysklad_state_href.blank?

    state = @ms_states.find { |s| s[:href] == mapping.moysklad_state_href }
    mapping.moysklad_state_name = state[:name] if state
  end

  def mapping_params
    params.require(:moysklad_order_status_mapping).permit(
      :moysklad_state_href, :moysklad_state_name, :order_status_id
    )
  end
end
