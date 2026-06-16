class MoyskladsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_moysklad, only: %i[ show edit update destroy check add_order_webhook order_settings ]

  def index
    @moysklads = Moysklad.all.order(created_at: :desc)
  end

  def show
    load_reference_data
    @status_mappings = MoyskladOrderStatusMapping.includes(:order_status).order(:id)
    @field_mappings = @moysklad.moysklad_order_field_mappings.order(:id)
    @order_statuses = OrderStatus.order(:position)
  end

  def new
    @moysklad = Moysklad.new
  end

  def edit
  end

  def create
    @moysklad = Moysklad.new(moysklad_params)

    respond_to do |format|
      if @moysklad.save
        format.html { redirect_to moysklad_path(@moysklad), notice: t('.created') }
        format.turbo_stream do
          flash[:notice] = t('.created')
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.update(:moysklads_actions,partial: "moysklads/actions"),
            turbo_stream.append("moysklads", partial: "moysklads/moysklad", locals: { moysklad: @moysklad })
          ]
        end
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @moysklad.update(moysklad_params)
        format.html { redirect_to moysklad_path(@moysklad), notice: t('.updated') }
        format.turbo_stream do
          flash[:notice] = t('.updated')
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(dom_id(@moysklad), partial: "moysklads/moysklad", locals: { moysklad: @moysklad })
          ]
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @moysklad.destroy!

    respond_to do |format|
      format.html { redirect_to moysklads_path, notice: t('.destroyed') }
      format.turbo_stream do
        flash[:notice] = t('.destroyed')
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.update(:moysklads_actions,partial: "moysklads/actions"),
          turbo_stream.remove(dom_id(@moysklad))
        ]
      end
    end
  end

  def add_order_webhook
    success, messages = MoyskladApi::Webhook.add_order_webhooks(moysklad: @moysklad)

    if success
      flash[:notice] = t(".webhook_success", message: Array(messages).join(", "))
    else
      flash[:alert] = t(".webhook_error", messages: messages.join(", "))
    end

    respond_to do |format|
      format.html { redirect_to moysklad_path(@moysklad) }
      format.turbo_stream { render turbo_stream: [render_turbo_flash] }
    end
  end

  def order_settings
    load_reference_data
    attrs = order_settings_params.to_h
    apply_default_ad_source_name!(attrs)

    if @moysklad.update(attrs)
      redirect_to moysklad_path(@moysklad), notice: t("moysklads.order_settings.updated")
    else
      @status_mappings = MoyskladOrderStatusMapping.includes(:order_status).order(:id)
      @field_mappings = @moysklad.moysklad_order_field_mappings.order(:id)
      @order_statuses = OrderStatus.order(:position)
      render :show, status: :unprocessable_entity
    end
  end

  def check
    success, messages = @moysklad.api_work?
    
    if success
      flash[:notice] = t('.check_success')
    else
      flash[:alert] = t('.check_error', messages: messages.join(', '))
    end

    respond_to do |format|
      # format.html { redirect_to moysklad_path(@moysklad) }
      format.turbo_stream do
        render turbo_stream: [render_turbo_flash]
      end
    end
  end

  private

  def load_reference_data
    @api_ok, @api_errors = @moysklad.api_work?
    return unless @api_ok

    @organizations = MoyskladApi::ReferenceData.organizations(@moysklad)
    @stores = MoyskladApi::ReferenceData.stores(@moysklad)
    metadata = MoyskladApi::ReferenceData.customerorder_metadata(@moysklad)
    @ms_states = MoyskladApi::ReferenceData.states_from_metadata(metadata)
    @ms_attributes = MoyskladApi::ReferenceData.customerorder_attributes(@moysklad)
    @ad_source_attribute = @ms_attributes.find do |row|
      row[:type] == "customentity" && row[:name] == Moysklad::AD_SOURCE_ATTRIBUTE_NAME
    end
    @ms_ad_source_entities =
      if @ad_source_attribute&.dig(:custom_entity_meta_href).present?
        MoyskladApi::ReferenceData.custom_entity_values(
          @moysklad,
          @ad_source_attribute[:custom_entity_meta_href]
        )
      else
        []
      end
  rescue StandardError => e
    Rails.logger.warn "[MoyskladsController] load_reference_data: #{e.message}"
    @organizations ||= []
    @stores ||= []
    @ms_states ||= []
    @ms_attributes ||= []
    @ms_ad_source_entities ||= []
  end

  def apply_default_ad_source_name!(attrs)
    href = attrs["default_ad_source_href"]
    if href.present?
      entity = @ms_ad_source_entities&.find { |row| row[:href] == href }
      attrs["default_ad_source_name"] = entity[:name] if entity
    else
      attrs["default_ad_source_name"] = nil
    end
  end

  def set_moysklad
    @moysklad = Moysklad.find(params[:id])
  end

  def moysklad_params
    params.require(:moysklad).permit(:title, :api_key, :api_password)
  end

  def order_settings_params
    params.require(:moysklad).permit(
      :organization_href,
      :store_href,
      :order_number_prefix,
      :title,
      :default_ad_source_href,
      :orders_integration_start_at
    )
  end
end
