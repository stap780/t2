# frozen_string_literal: true

class InsalesOrderFieldMappingsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_insale
  before_action :set_mapping, only: %i[edit update destroy]
  before_action :load_insales_fields, only: %i[new edit create update]

  def new
    @mapping = @insale.insales_order_field_mappings.new
  end

  def edit; end

  def create
    @mapping = @insale.insales_order_field_mappings.new(mapping_params)
    apply_field_title(@mapping)

    respond_to do |format|
      if @mapping.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(@insale, :insales_order_field_mappings),
              partial: "insales_order_field_mappings/mapping",
              locals: { mapping: @mapping, insale: @insale }
            )
          ]
        end
        format.html { redirect_to insale_path(@insale, anchor: "field_mappings"), notice: t(".success") }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    @mapping.assign_attributes(mapping_params)
    apply_field_title(@mapping)

    respond_to do |format|
      if @mapping.save
        flash.now[:success] = t(".success")
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@mapping),
              partial: "insales_order_field_mappings/mapping",
              locals: { mapping: @mapping, insale: @insale }
            )
          ]
        end
        format.html { redirect_to insale_path(@insale, anchor: "field_mappings"), notice: t(".success") }
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
      format.html { redirect_to insale_path(@insale, anchor: "field_mappings"), notice: t(".success") }
    end
  end

  private

  def set_insale
    @insale = Insale.find(params[:insale_id])
  end

  def set_mapping
    @mapping = @insale.insales_order_field_mappings.find(params[:id])
  end

  def load_insales_fields
    return unless @insale.api_work?[0]

    @insales_fields = Insales::ReferenceData.order_fields(@insale)
  end

  def apply_field_title(mapping)
    return if @insales_fields.blank?

    field = @insales_fields.find { |row| row[:id].to_s == mapping.insales_field_id.to_s }
    return unless field

    mapping.insales_field_handle = field[:handle] if field[:handle].present?
    mapping.insales_field_title = field[:title]
  end

  def mapping_params
    params.require(:insales_order_field_mapping).permit(
      :source_key, :insales_field_id, :insales_field_handle, :insales_field_title
    )
  end
end
