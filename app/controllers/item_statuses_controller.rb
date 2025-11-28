class ItemStatusesController < ApplicationController
  before_action :set_item_status, only: %i[show edit update destroy]
  include ActionView::RecordIdentifier

  def index
    @item_statuses = ItemStatus.order(:position)
  end

  def show
  end

  def new
    @item_status = ItemStatus.new
  end

  def edit; end

  def create
    @item_status = ItemStatus.new(item_status_params)

    respond_to do |format|
      if @item_status.save
        flash.now[:success] = t('.success')
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "item_statuses",
              partial: "item_statuses/item_status",
              locals: { item_status: @item_status }
            )
          ]
        }
        format.html { redirect_to item_status_url(@item_status), notice: t('.success') }
        format.json { render :show, status: :created, location: @item_status }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @item_status.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @item_status.update(item_status_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@item_status),
              partial: "item_statuses/item_status",
              locals: { item_status: @item_status }
            )
          ]
        end
        format.html { redirect_to item_status_url(@item_status), notice: t('.success') }
        format.json { render :show, status: :ok, location: @item_status }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @item_status.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @item_status.destroy!
    flash.now[:success] = t('.success')
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(dom_id(@item_status)),
          render_turbo_flash
        ]
      end
      format.html { redirect_to item_statuses_path, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  private

  def set_item_status
    @item_status = ItemStatus.find(params[:id])
  end

  def item_status_params
    params.require(:item_status).permit(:title, :color, :position)
  end
end

