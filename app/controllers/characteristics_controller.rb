class CharacteristicsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_property
  before_action :set_characteristic, only: %i[edit update destroy]

  def new
    @characteristic = @property.characteristics.build
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def create
    @characteristic = @property.characteristics.build(characteristic_params)
    respond_to do |format|
      if @characteristic.save
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              'property_characteristics',
              partial: "characteristics/characteristic",
              locals: { characteristic: @characteristic, property: @property }
            )
          ]
        end
        format.html { redirect_to property_path(@property), notice: t('.success') }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    @characteristic.update(characteristic_params)
    respond_to do |format|
      if @characteristic.update(characteristic_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.update(
              dom_id(@characteristic),
              partial: "characteristics/characteristic",
              locals: { characteristic: @characteristic, property: @property }
            )
          ]
        end
        format.html { redirect_to property_path(@property), notice: t('.success') }
        format.json { render :show, status: :ok, location: @characteristic }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @characteristic.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @characteristic.destroy
    respond_to do |format|
      format.turbo_stream
    end
  end

  def search
    # Получаем title из разных возможных мест
    search_title = params[:title] || params.dig(:characteristic, :title)
    
    # Получаем property_id из разных возможных мест
    property_id = params[:property_id] || params.dig(:characteristic, :property_id)
    
    if search_title.present? && property_id.present?
      property = Property.find(property_id)
      @search_results = property.characteristics
                                 .where("title ILIKE ?", "%#{search_title}%")
                                 .limit(20)
                                 .map { |c| { title: c.title, id: c.id } }
      render json: @search_results, status: :ok
    else
      render json: [], status: :ok
    end
  end

  private

  def set_property
    if params[:property_id].present?
      @property = Property.find(params[:property_id]).order(:title)
    else
      # Для новых записей создаем временный объект
      @property = Property.new
    end
  end

  def set_characteristic
    @characteristic = @property.characteristics.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @characteristic = Characteristic.new(id: params[:id])
  end

  def characteristic_params
    params.require(:characteristic).permit(:title)
  end

end
