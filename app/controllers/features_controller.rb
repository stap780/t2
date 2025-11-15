class FeaturesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_product
  before_action :set_feature, only: %i[ show edit update destroy ]

  def index
    @features = @product.features.order(:id)
  end

  def show
  end

  def new
    @feature = @product.features.build
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def edit; end

  def create
    @feature = @product.features.build(feature_params)

    respond_to do |format|
      if @feature.save
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              'features',
              partial: "features/feature",
              locals: { feature: @feature, product: @product }
            )
          ]
        end
        format.html { redirect_to @feature, notice: "Feature was successfully created." }
        format.json { render :show, status: :created, location: @feature }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @feature.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @feature.update(feature_params)
    respond_to do |format|
      if @feature.update(feature_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.update(
              dom_id(@feature),
              partial: "features/feature",
              locals: { feature: @feature, product: @product }
            )
          ]
        end
        format.html { redirect_to product_path(@product), notice: t('.success') }
        format.json { render :show, status: :ok, location: @feature }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @feature.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @feature.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @feature.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@feature)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to product_path(@product), notice: t(".success") }
      format.json { head :no_content }
    end
  end

  def update_characteristics
    set_product
    set_feature
    if params[:property_id].present?
      @feature.property_id = params[:property_id].to_i
      @feature.characteristic_id = nil
      # Перезагружаем property для получения characteristics
      @feature.property = Property.find(@feature.property_id) if @feature.property_id.present?
    end
    
    respond_to do |format|
      format.turbo_stream
    end
  end

  private

    def set_product
      if params[:product_id].present?
        @product = Product.find(params[:product_id])
      else
        @product = Product.new
      end
    end

    def set_feature
      @feature = @product.features.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      @feature = Feature.new(id: params[:id])      
    end

    def feature_params
      params.require(:feature).permit(:product_id, :property_id, :characteristic_id)
    end

end
