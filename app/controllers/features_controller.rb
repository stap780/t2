class FeaturesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_featureable
  before_action :set_feature, only: %i[ show edit update destroy ]

  def index
    @features = @featureable.features.order(:id)
  end

  def show
  end

  def new
    @feature = @featureable.features.build
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def edit; end

  def create
    @feature = @featureable.features.build(feature_params)

    respond_to do |format|
      if @feature.save
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              'features',
              partial: "features/feature",
              locals: { feature: @feature, featureable: @featureable }
            )
          ]
        end
        format.html { redirect_to @feature, notice: t('.success') }
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
              locals: { feature: @feature, featureable: @featureable }
            )
          ]
        end
        format.html { redirect_to polymorphic_path(@featureable), notice: t('.success') }
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
      format.html { redirect_to polymorphic_path(@featureable), notice: t(".success") }
      format.json { head :no_content }
    end
  end

  def update_characteristics
    set_featureable
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

    def set_featureable
      if params[:product_id].present?
        @featureable = Product.find(params[:product_id])
      elsif params[:detal_id].present?
        @featureable = Detal.find(params[:detal_id])
      else
        # Для новых записей определяем по параметрам
        if params[:product_id] == nil && params[:detal_id] == nil
          # Пытаемся определить из feature_params или создаем новый объект
          if params[:feature] && params[:feature][:featureable_type]
            @featureable = params[:feature][:featureable_type].constantize.new
          else
            @featureable = Product.new
          end
        end
      end
    end

    def set_feature
      if @featureable.persisted?
        @feature = @featureable.features.find(params[:id])
      else
        @feature = Feature.new(id: params[:id])
      end
    rescue ActiveRecord::RecordNotFound
      @feature = Feature.new(id: params[:id])      
    end

    def feature_params
      params.require(:feature).permit(:property_id, :characteristic_id)
    end

end
