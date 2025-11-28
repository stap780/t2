class IncaseTipsController < ApplicationController
  before_action :set_incase_tip, only: %i[show edit update destroy sort]
  include ActionView::RecordIdentifier

  def index
    @incase_tips = IncaseTip.order(:position)
  end

  def show
  end

  def new
    @incase_tip = IncaseTip.new
  end

  def edit; end

  def create
    @incase_tip = IncaseTip.new(incase_tip_params)

    respond_to do |format|
      if @incase_tip.save
        flash.now[:success] = t('.success')
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "incase_tips",
              partial: "incase_tips/incase_tip",
              locals: { incase_tip: @incase_tip }
            )
          ]
        }
        format.html { redirect_to incase_tip_url(@incase_tip), notice: t('.success') }
        format.json { render :show, status: :created, location: @incase_tip }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @incase_tip.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @incase_tip.update(incase_tip_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@incase_tip),
              partial: "incase_tips/incase_tip",
              locals: { incase_tip: @incase_tip }
            )
          ]
        end
        format.html { redirect_to incase_tip_url(@incase_tip), notice: t('.success') }
        format.json { render :show, status: :ok, location: @incase_tip }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @incase_tip.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @incase_tip.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @incase_tip.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@incase_tip)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to incase_tips_path, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  def sort
    position = params[:position] || params[:new_position]
    @incase_tip.insert_at(position.to_i) if position.present?
    
    respond_to do |format|
      format.turbo_stream do
        @incase_tips = IncaseTip.order(:position)
        render turbo_stream: turbo_stream.replace(
          "incase_tips",
          partial: "incase_tips/index_list",
          locals: { incase_tips: @incase_tips }
        )
      end
      format.json { head :ok }
      format.html { head :ok }
    end
  end

  private

  def set_incase_tip
    @incase_tip = IncaseTip.find(params[:id])
  end

  def incase_tip_params
    params.require(:incase_tip).permit(:title, :color, :position)
  end
end

