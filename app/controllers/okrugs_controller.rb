class OkrugsController < ApplicationController
  before_action :set_okrug, only: %i[show edit update destroy sort]
  include ActionView::RecordIdentifier

  def index
    @okrugs = Okrug.order(:position)
  end

  def show
  end

  def new
    @okrug = Okrug.new
  end

  def edit; end

  def create
    @okrug = Okrug.new(okrug_params)

    respond_to do |format|
      if @okrug.save
        flash.now[:success] = t('.success')
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.prepend(
              "okrugs",
              partial: "okrugs/okrug",
              locals: { okrug: @okrug }
            )
          ]
        }
        format.html { redirect_to okrug_url(@okrug), notice: t('.success') }
        format.json { render :show, status: :created, location: @okrug }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @okrug.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @okrug.update(okrug_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@okrug),
              partial: "okrugs/okrug",
              locals: { okrug: @okrug }
            )
          ]
        end
        format.html { redirect_to okrug_url(@okrug), notice: t('.success') }
        format.json { render :show, status: :ok, location: @okrug }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @okrug.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @okrug.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @okrug.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@okrug)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to okrugs_path, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  def sort
    position = params[:position] || params[:new_position]
    @okrug.insert_at(position.to_i) if position.present?
    
    respond_to do |format|
      format.turbo_stream do
        @okrugs = Okrug.order(:position)
        render turbo_stream: turbo_stream.replace(
          "okrugs",
          partial: "okrugs/index_list",
          locals: { okrugs: @okrugs }
        )
      end
      format.json { head :ok }
      format.html { head :ok }
    end
  end

  private

  def set_okrug
    @okrug = Okrug.find(params[:id])
  end

  def okrug_params
    params.require(:okrug).permit(:title, :position)
  end
end

