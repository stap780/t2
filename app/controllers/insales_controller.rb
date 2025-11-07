class InsalesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_insale, only: %i[ show edit update destroy check add_order_webhook ]

  # GET /insales
  def index
    @insales = Insale.all.order(created_at: :desc)
  end

  # GET /insales/1
  def show
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
          turbo_stream.remove(dom_id(@insale))
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
      format.html { redirect_to insales_path }
      format.turbo_stream do
        render turbo_stream: [render_turbo_flash]
      end
    end
  end

  # POST /insales/:id/add_order_webhook
  def add_order_webhook
    success, messages = Insale.add_order_webhook(rec: @insale)
    
    if success
      flash[:notice] = t('.webhook_success', message: messages.join(', '))
    else
      flash[:alert] = t('.webhook_error', messages: messages.join(', '))
    end

    respond_to do |format|
      format.html { redirect_to insales_path }
      format.turbo_stream do
        render turbo_stream: [render_turbo_flash]
      end
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
