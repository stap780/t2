class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit copy update destroy delete_image sort_image add_image ]
  include ActionView::RecordIdentifier

  def index
    @search = Product.includes(:features, :variants, images: [:file_attachment, :file_blob]).ransack(params[:q])
    @search.sorts = "id desc" if @search.sorts.empty?
    @products = @search.result(distinct: true).paginate(page: params[:page], per_page: Rails.env.development? ? 30 : 100)
  end

  def search
    if params[:title].present?
      @search_results = Variant.ransack(sku_or_barcode_or_product_title_cont: "%#{params[:title]}%").result.map { |var| {title: "#{var.product&.title} - #{var.sku}", id: var.id} }.reject(&:blank?)
      render json: @search_results, status: :ok
    else
      render json: [], status: :unprocessable_entity
    end
  end

  def show
    @product = Product.find(params[:id])
  end

  def new
    @product = Product.new
    @product.variants.build
  end

  def edit
    @product.images.includes([:file_attachment, :file_blob])
    @features = @product.features
    @variants = @product.variants.order(id: :asc)
  end

  def create
    check_positions(params[:product][:images_attributes]) if params[:product][:images_attributes]
    @product = Product.new(product_params)
    respond_to do |format|
      if @product.save
        format.html { redirect_to edit_product_path(@product), notice: t(".success") }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  def copy
    @new_product = @product.dup
    @new_product.title = "(COPY) #{@new_product.title} - #{Time.now.to_s}"
    new_features = @product.features.select(:property_id, :characteristic_id).map(&:attributes)
    @new_product.features_attributes = new_features
    new_vars = @product.variants.select(:sku, :price).map(&:attributes)
    @new_product.variants_attributes = new_vars
    
    # Копируем изображения
    if @product.images.any?
      @product.images.each do |image|
        new_image = @new_product.images.build
        if image.file.attached?
          new_image.file.attach(
            io: image.file.download,
            filename: image.file.filename.to_s,
            content_type: image.file.content_type
          )
        end
        new_image.position = image.position
      end
    end
    
    respond_to do |format|
      if @new_product.save!
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash
          ]
        end
        format.html { redirect_to products_path, notice: t('.success') }
        format.json { render :show, status: :created, location: @new_product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @new_product.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    check_positions(params[:product][:images_attributes]) if params[:product][:images_attributes]
    respond_to do |format|
      if @product.update(product_params)
        format.html { redirect_to products_path, notice: t(".success") }
        format.json { render :show, status: :ok, location: @product }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @product.errors, status: :unprocessable_entity }
      end
    end
  end

  def sort_image
    # switch off because we use position input inside form and save position with form save
    # @image = @product.images.find_by_id(params[:sort_item_id])
    # @image.insert_at params[:new_position]
    head :ok
  end

  def add_image
    @image = @product.images.build
    
    # Прикрепляем файл из signed_id (Direct Upload)
    if params[:file].present?
      @image.file.attach(params[:file])
    end
    
    respond_to do |format|
      if @image.save
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            dom_id(@product, :images),
            partial: "images/image",
            locals: { product: @product, image: @image }
          )
        end
        format.json { render json: { success: true, image_id: @image.id }, status: :created }
      else
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "image-errors",
            partial: "shared/errors",
            locals: { object: @image }
          )
        end
        format.json { render json: { success: false, errors: @image.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def delete_image
    @image = @product.images.find(params[:image_id])
    @image.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.remove(dom_id(@image))
      end
      format.html { redirect_to edit_product_path(@product), notice: 'Image deleted.' }
      format.json { head :no_content }
    end
  end

  def price_edit
    if params[:product_ids]
      @products = Product.where(id: params[:product_ids])
      respond_to do |format|
        format.turbo_stream
      end
    else
      notice = 'Выберите позиции'
      redirect_to products_url, alert: notice
    end
  end

  def price_update
    if params[:product_ids]
      field_type = params[:product_price][:field_type]
      move = params[:product_price][:move]
      shift = params[:product_price][:shift]
      points = params[:product_price][:points]
      round = params[:product_price][:round]

      ProductPriceUpdateJob.perform_later(params[:product_ids], field_type, move, shift, points, round)
      render turbo_stream:
        turbo_stream.update(
          'modal',
          partial: 'shared/pending_bulk_text'
        )
    else
      notice = 'Выберите товары'
      redirect_to products_url, alert: notice
    end
  end

  def destroy
    check_destroy = @product.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @product.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@product)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to products_path, notice: t(".success") }
      format.json { head :no_content }
    end
  end

  private

  def set_product
    @product = Product.find(params[:id])
  end

  def check_positions(images)
    if images.present?
      images.values.each.with_index do |image, index|
        if image["id"]
          image = Image.find(image["id"])
          image.set_list_position(100 + index)
        end
      end
    end
  end

  def product_params
    params.require(:product).permit(
      :status, :tip, :title, :description,
      features_attributes: [:id, :product_id, :property_id, :characteristic_id, :_destroy],
      images_attributes: [:id, :product_id, :position, :file, :_destroy],
      variants_attributes: [:id, :product_id, :sku, :barcode, :quantity, :cost_price, :price, :_destroy]
    )
  end

end
