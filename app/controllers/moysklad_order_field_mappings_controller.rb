# frozen_string_literal: true

class MoyskladOrderFieldMappingsController < ApplicationController
  before_action :set_moysklad
  before_action :set_mapping, only: %i[edit update destroy]
  before_action :load_ms_attributes, only: %i[new edit create update]
  include ActionView::RecordIdentifier

  def new
    @mapping = @moysklad.moysklad_order_field_mappings.new
  end

  def edit; end

  def create
    @mapping = @moysklad.moysklad_order_field_mappings.new(mapping_params)
    apply_attribute_name(@mapping)

    respond_to do |format|
      if @mapping.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "moysklad_order_field_mappings",
              partial: "moysklad_order_field_mappings/mapping",
              locals: { mapping: @mapping }
            )
          ]
        end
        format.html { redirect_to moysklad_path(@moysklad, anchor: "field_mappings"), notice: t(".success") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    @mapping.assign_attributes(mapping_params)
    apply_attribute_name(@mapping)

    respond_to do |format|
      if @mapping.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@mapping),
              partial: "moysklad_order_field_mappings/mapping",
              locals: { mapping: @mapping }
            )
          ]
        end
        format.html { redirect_to moysklad_path(@moysklad, anchor: "field_mappings"), notice: t(".success") }
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
      format.html { redirect_to moysklad_path(@moysklad, anchor: "field_mappings"), notice: t(".success") }
    end
  end

  private

  def set_moysklad
    @moysklad = Moysklad.find(params[:moysklad_id])
  end

  def set_mapping
    @mapping = @moysklad.moysklad_order_field_mappings.find(params[:id])
  end

  def load_ms_attributes
    return unless @moysklad.api_work?[0]

    @ms_attributes = MoyskladApi::ReferenceData.customerorder_attributes(@moysklad)
  end

  def apply_attribute_name(mapping)
    return if @ms_attributes.blank? || mapping.ms_attribute_href.blank?

    attr = @ms_attributes.find { |a| a[:href] == mapping.ms_attribute_href }
    mapping.ms_attribute_name = attr[:name] if attr
  end

  def mapping_params
    params.require(:moysklad_order_field_mapping).permit(
      :source_key, :ms_attribute_href, :ms_attribute_name
    )
  end
end
