class IncaseStatusesController < ApplicationController
  before_action :set_incase_status, only: %i[show edit update destroy sort]
  include ActionView::RecordIdentifier

  def index
    @incase_statuses = IncaseStatus.order(:position)
  end

  def show
  end

  def new
    @incase_status = IncaseStatus.new
  end

  def edit; end

  def create
    @incase_status = IncaseStatus.new(incase_status_params)

    respond_to do |format|
      if @incase_status.save
        flash.now[:success] = t('.success')
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "incase_statuses",
              partial: "incase_statuses/incase_status",
              locals: { incase_status: @incase_status }
            )
          ]
        }
        format.html { redirect_to incase_status_url(@incase_status), notice: t('.success') }
        format.json { render :show, status: :created, location: @incase_status }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @incase_status.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @incase_status.update(incase_status_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@incase_status),
              partial: "incase_statuses/incase_status",
              locals: { incase_status: @incase_status }
            )
          ]
        end
        format.html { redirect_to incase_status_url(@incase_status), notice: t('.success') }
        format.json { render :show, status: :ok, location: @incase_status }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @incase_status.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @incase_status.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @incase_status.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@incase_status)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to incase_statuses_path, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  def sort
    position = params[:position] || params[:new_position]
    @incase_status.insert_at(position.to_i) if position.present?
    
    respond_to do |format|
      format.turbo_stream do
        @incase_statuses = IncaseStatus.order(:position)
        render turbo_stream: turbo_stream.replace(
          "incase_statuses",
          partial: "incase_statuses/index_list",
          locals: { incase_statuses: @incase_statuses }
        )
      end
      format.json { head :ok }
      format.html { head :ok }
    end
  end

  private

  def set_incase_status
    @incase_status = IncaseStatus.find(params[:id])
  end

  def incase_status_params
    params.require(:incase_status).permit(:title, :color, :position)
  end
end

