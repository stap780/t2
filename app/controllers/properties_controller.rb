class PropertiesController < ApplicationController
  before_action :set_property, only: %i[show edit update destroy]
  include ActionView::RecordIdentifier

  def index
    @properties = Property.includes(:characteristics).order(:id)
  end

  def show
    @search = @property.characteristics.ransack(params[:q])
    @search.sorts = 'id asc' if @search.sorts.empty?
    @characteristics = @search.result(distinct: true).paginate(page: params[:page], per_page: 100)
  end

  def new
    @property = Property.new
    @property.characteristics.build
  end

  def edit; end

  def create
    @property = Property.new(property_params)

    respond_to do |format|
      if @property.save
        flash.now[:success] = t('.success')
        format.turbo_stream {
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              "properties",
              partial: "properties/property",
              locals: { property: @property }
            )
          ]
        }
        format.html { redirect_to property_url(@property), notice: t('.success') }
        format.json { render :show, status: :created, location: @property }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @property.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @property.update(property_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@property),
              partial: "properties/property",
              locals: { property: @property }
            )
          ]
        end
        format.html { redirect_to property_url(@property), notice: t('.success') }
        format.json { render :show, status: :ok, location: @property }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @property.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    check_destroy = @property.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @property.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@property)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to properties_path, notice: t('.success') }
      format.json { head :no_content }
    end
  end

  def characteristics
    @turbo_frame_id = params[:turbo_frame_id]
    property_id = params[:property_id]
    product_id = params[:product_id]
    
    # Проверяем наличие обязательных параметров
    return head :bad_request unless @turbo_frame_id.present? && property_id.present?
    
    @feature_id_str = @turbo_frame_id.sub('feature_', '')
    
    # Находим product из параметров
    @product = product_id ? Product.find(product_id.to_i) : Product.new
    
    # Пытаемся найти feature (для сохраненных features с числовым ID)
    feature_id = @feature_id_str.to_i if @feature_id_str.match?(/^\d+$/) && @feature_id_str.to_i < 2147483647
    @feature = feature_id ? @product.features.find_by(id: feature_id) : nil
    
    # Если feature не найден, создаем новый (для новых features с hash ID)
    @feature ||= @product.features.build
    
    # Обновляем property_id
    if property_id.present?
      @feature.property_id = property_id.to_i
      @feature.characteristic_id = nil
      @feature.property = Property.find(property_id) if @feature.property_id.present?
    end
    
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(@turbo_frame_id, partial: "features/feature", locals: { feature: @feature, product: @product })
        ]
      end
    end
  end

  def search
    if params[:title].present?
      @search_results = Property.where("title ILIKE ?", "%#{params[:title]}%")
                                 .limit(20)
                                 .map { |p| { title: p.title, id: p.id } }
      render json: @search_results, status: :ok
    else
      render json: [], status: :ok
    end
  end

  private

  def set_property
    @property = Property.find(params[:id])
  end

  def property_params
    params.require(:property).permit(:title, characteristics_attributes: [:id, :title])
  end


end
