class DetalsController < ApplicationController
  before_action :set_detal, only: %i[ show edit update get_oszz destroy ]
  include ActionView::RecordIdentifier
  include SearchQueryRansack
  include DownloadExcel
  include BulkDelete

  def index
    @search = Detal.ransack(search_params)
    @search.sorts = "id desc" if @search.sorts.empty?
    @detals = @search.result(distinct: true).paginate(page: params[:page], per_page: 100)
  end

  def show
  end

  def new
    @detal = Detal.new
  end

  def edit
    @features = @detal.features
  end

  def create
    @detal = Detal.new(detal_params)
    respond_to do |format|
      if @detal.save
        format.html { redirect_to detals_path, notice: t(".success") }
        format.json { render :show, status: :created, location: @detal }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @detal.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @detal.update(detal_params)
        format.html { redirect_to detals_path, notice: t(".success") }
        format.json { render :show, status: :ok, location: @detal }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @detal.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @detal.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @detal.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@detal)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to detals_path, notice: t(".success") }
      format.json { head :no_content }
    end
  end

	def get_oszz
    result = @detal.get_oszz
    respond_to do |format|
      format.turbo_stream do
        if result[:success] == true
          @detal.update!(oszz_price: result[:price])
          flash.now[:success] = result[:message]
          render turbo_stream: [
            turbo_stream.replace(dom_id(@detal), partial: "detals/detal", locals: { detal: @detal }),
            render_turbo_flash
          ]
        else
          flash.now[:notice] = result[:message]
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to detals_path, notice: result[:message] }
      format.json { head :no_content }
    end
	end

  private

  def set_detal
    @detal = Detal.find(params[:id])
  end

  def detal_params
    params.require(:detal).permit(
      :status, :sku, :title, :desc, :oszz_price,
      features_attributes: [:id, :property_id, :characteristic_id, :_destroy]
    )
  end
end
