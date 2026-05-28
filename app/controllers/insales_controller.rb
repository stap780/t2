class InsalesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_insale, only: %i[ show edit update destroy check fetch_orders add_order_webhook add_order_update_webhook ]

  # GET /insales
  def index
    @insales = Insale.all.order(created_at: :desc)
  end

  # GET /insales/1
  def show
    @api_ok, @api_errors = @insale.api_work?
    @status_mappings = @insale.insales_order_status_mappings
                               .includes(:order_status)
                               .order(:insales_custom_status_permalink, :insales_financial_status)
    @field_mappings = @insale.insales_order_field_mappings.order(:id)
    @insales_fields = @api_ok ? Insales::ReferenceData.order_fields(@insale) : []
  end

  # GET /insales/new
  def new
    @insale = Insale.new
  end

  # GET /insales/1/edit
  def edit
  end

  def create
    @insale = Insale.new(insale_params)

    respond_to do |format|
      if @insale.save
        format.html { redirect_to insales_path, notice: t('.created') }
        format.turbo_stream do
          flash[:notice] = t('.created')
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.update(:insales_actions,partial: "insales/actions"),
            turbo_stream.append("insales", partial: "insales/insale", locals: { insale: @insale })
          ]
        end
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @insale.update(insale_params)
        format.html { redirect_to insales_path, notice: t('.updated') }
        format.turbo_stream do
          flash[:notice] = t('.updated')
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(dom_id(@insale), partial: "insales/insale", locals: { insale: @insale })
          ]
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @insale.destroy!

    respond_to do |format|
      format.html { redirect_to insales_path, notice: t('.destroyed') }
      format.turbo_stream do
        flash[:notice] = t('.destroyed')
        render turbo_stream: [
          render_turbo_flash,
          turbo_stream.remove(dom_id(@insale)),
          turbo_stream.update(:insales_actions, partial: "insales/actions")
        ]
        
      end
    end
  end

  # GET /insales/1/check
  def check
    success, messages = @insale.api_work?
    
    if success
      flash[:notice] = t('.check_success')
    else
      flash[:alert] = t('.check_error', messages: messages.join(', '))
    end

    respond_to do |format|
      # format.html { redirect_to insales_path }
      format.turbo_stream do
        render turbo_stream: [render_turbo_flash]
      end
    end
  end

  # GET /insales/:id/fetch_orders — импорт заказов в реестр и выгрузка в МС
  def fetch_orders
    stats = Insales::Orders::SyncAccount.call(insale: @insale)

    if stats.errors.include?("api_not_working")
      flash[:alert] = t(".fetch_error", message: t(".fetch_api_not_working"))
    elsif stats.errors.any?
      flash[:alert] = t(
        ".fetch_partial",
        imported: stats.imported,
        moysklad_created: stats.moysklad_created,
        errors: stats.errors.first(3).join("; ")
      )
    else
      flash[:notice] = t(
        ".fetch_success",
        imported: stats.imported,
        updated: stats.updated,
        skipped: stats.skipped,
        moysklad_created: stats.moysklad_created
      )
    end

    respond_to do |format|
      format.html { redirect_to insales_path }
      format.turbo_stream { render turbo_stream: [render_turbo_flash] }
    end
  end

  # POST /insales/:id/add_order_webhook
  def add_order_webhook
    render_webhook_result(@insale.add_order_webhook)
  end

  # POST /insales/:id/add_order_update_webhook
  def add_order_update_webhook
    render_webhook_result(@insale.add_order_update_webhook)
  end

  private

  def render_webhook_result(success, messages)
    message_text = messages.is_a?(Array) ? messages.join(", ") : messages.to_s
    if success
      flash[:notice] = t(".webhook_success", message: message_text)
    else
      flash[:alert] = t(".webhook_error", messages: message_text)
    end

    respond_to do |format|
      format.html { redirect_to insales_path }
      format.turbo_stream { render turbo_stream: [render_turbo_flash] }
    end
  end

  private

  def set_insale
    @insale = Insale.find(params[:id])
  end

  def insale_params
    params.require(:insale).permit(:api_key, :api_password, :api_link)
  end
end
