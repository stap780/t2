class MoyskladsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_moysklad, only: %i[ show edit update destroy check ]

  # GET /moysklads
  def index
    @moysklads = Moysklad.all.order(created_at: :desc)
  end

  # GET /moysklads/1
  def show
  end

  # GET /moysklads/new
  def new
    @moysklad = Moysklad.new
  end

  # GET /moysklads/1/edit
  def edit
  end

  def create
    @moysklad = Moysklad.new(moysklad_params)

    respond_to do |format|
      if @moysklad.save
        format.html { redirect_to moysklads_path, notice: t('.created') }
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
        format.html { redirect_to moysklads_path, notice: t('.updated') }
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

  # GET /moysklads/1/check
  def check
    success, messages = @moysklad.api_work?
    
    if success
      flash[:notice] = t('.check_success')
    else
      flash[:alert] = t('.check_error', messages: messages.join(', '))
    end

    respond_to do |format|
      format.html { redirect_to moysklads_path }
      format.turbo_stream do
        render turbo_stream: [render_turbo_flash]
      end
    end
  end

  private

  def set_moysklad
    @moysklad = Moysklad.find(params[:id])
  end

  def moysklad_params
    params.require(:moysklad).permit(:api_key, :api_password)
  end
end

