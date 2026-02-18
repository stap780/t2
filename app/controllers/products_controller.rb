class ProductsController < ApplicationController
  before_action :set_product, only: %i[ show edit copy update destroy sort_image refill sync_with_moysklad edit_status_inline update_status_inline ]
  after_action :clear_preloaded_detals, only: [:index, :edit, :update, :open_filter, :filter_price]
  include ActionView::RecordIdentifier
  include SearchQueryRansack
  include DownloadExcel
  include BulkDelete
  include PrintEtiketkas

  def index
    build_products_index(Product.all, search_params)
  end

  def open_filter
    @search = Product.ransack(search_params || {})
    @search.sorts = "id desc" if @search.sorts.empty?
    render params[:price].present? ? :filter_price : :filter
  end

  def filter_price
    audit_q = params[:audit_q]&.to_unsafe_h&.compact_blank&.symbolize_keys
    base_scope = if audit_q.present?
      ids = Audited::Audit.where(associated_type: "Product").ransack(audit_q).result.distinct.pluck(:associated_id).compact.uniq
      Product.where(id: ids)
    else
      Product.all
    end
    build_products_index(base_scope, params[:q] || {})
    render :index
  end

  def build_products_index(base_scope, product_params)
    hash = product_params.respond_to?(:to_unsafe_h) ? product_params.to_unsafe_h : product_params.to_h
    @search = base_scope.ransack(hash)
    @search.sorts = "id desc" if @search.sorts.empty?
    
    # Проверяем, используется ли сортировка по полям вариантов
    sorting_by_variants_price = @search.sorts.any? { |sort| sort.name.to_s == 'variants_price' }
    sorting_by_variants_quantity = @search.sorts.any? { |sort| sort.name.to_s == 'variants_quantity' }
    
    # COUNT запрос БЕЗ includes (быстрый) - Ransack сам добавит нужные JOIN для условий поиска
    count_result = @search.result(distinct: true)
    total_count = count_result.count
    
    # Для основного запроса добавляем select при сортировке по полям вариантов
    # Согласно документации Ransack: при distinct: true и сортировке по колонке из ассоциированной таблицы
    # нужно явно добавить эту колонку в SELECT через .select
    # https://www.rubydoc.info/gems/ransack/1.8.7#problem-with-distinct-selects
    base_result = if sorting_by_variants_price || sorting_by_variants_quantity
      # Формируем список колонок для SELECT в зависимости от используемых сортировок
      select_columns = ["products.*"]
      select_columns << "variants.price" if sorting_by_variants_price
      select_columns << "variants.quantity" if sorting_by_variants_quantity
      
      @search.result(distinct: true).select(select_columns.join(", "))
    else
      @search.result(distinct: true)
    end
    
    # Данные С includes (для отображения, избегаем N+1)
    @products = base_result.includes(:features, :variants, images: [:file_attachment, :file_blob])
                           .paginate(page: params[:page], per_page: 100)
    
    @products.total_entries = total_count
    
    # Preload Detal records to avoid N+1 queries
    product_ids = @products.map(&:id)
    # Use pluck to get all SKUs in one query instead of iterating through loaded objects
    skus = Variant.where(product_id: product_ids).pluck(:sku).compact.uniq if product_ids.any?
    # Use pluck to load only sku and oszz_price (faster than loading full objects)
    detals_by_sku = Detal.where(sku: skus).pluck(:sku, :oszz_price).to_h if skus&.any?
    Variant.preload_detals(detals_by_sku || {})
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
    
    # Preload Detal для oszz_price (избегаем N+1)
    skus = @variants.map(&:sku).compact.uniq
    detals_by_sku = Detal.where(sku: skus).pluck(:sku, :oszz_price).to_h if skus.any?
    Variant.preload_detals(detals_by_sku || {})
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
        format.turbo_stream { redirect_to products_path(format: :html), notice: t(".success") }
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

  def price_edit
    if params[:product_ids]
      @products = Product.where(id: params[:product_ids])
      respond_to do |format|
        format.turbo_stream
      end
    else
      respond_to do |format|
        format.turbo_stream do
          flash.now[:notice] = 'Выберите позиции'
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
    end
  end

  def price_update
    if params[:product_ids]
      field_type = params[:product_price][:field_type]
      move = params[:product_price][:move]
      shift = params[:product_price][:shift]
      points = params[:product_price][:points]
      round = params[:product_price][:round]

      ProductPriceUpdateJob.perform_later(params[:product_ids], field_type, move, shift, points, round, Current.user&.id)
      respond_to do |format|
        flash.now[:success] = 'Starting price update...'
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash
        end
      end
    end
  end

  def destroy
    check_destroy = @product.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      error_message = @product.errors.full_messages.join(' ')
      flash.now[:error] = error_message.presence || t('.error')
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

  def refill
    detal = nil

    if @product.variants.first&.sku.present? #&& @product.status == 'in_progress' || @product.status == 'draft'
      detal = Detal.find_by_sku(@product.variants.first&.sku)
    end

    if detal.present?
      @product.title = detal.title
      @product.description = detal.desc
      # Удаляем существующие features и копируем новые из detal в product
      @product.features.destroy_all
      new_features = detal.features.select(:property_id, :characteristic_id).map(&:attributes)
      @product.features_attributes = new_features
      @product.save! # сохраняем, иначе во вьюхе product.features.order(...) грузит из БД и новые features не видны
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(dom_id(@product), partial: "products/form", locals: { product: @product }),
            render_turbo_flash
          ]
        end
      end
    else
      flash.now[:notice] = 'Продукт не может быть заполнен. Нет мастер карточки.'
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
    end

  end

  def sync_with_moysklad
    if @product.has_moysklad_binding?
      MoyskladSyncProductJob.perform_later(@product.id)
      flash_message = t("products.sync_with_moysklad_started")
      flash_type = :notice
    else
      # flash_message = t("products.sync_with_moysklad_no_binding")
      # flash_type = :alert
      service = Moysklad::SyncProductService.new(@product, Moysklad.first)
      result = service.call
      
      if result[:success]
        flash_message = t("products.sync_with_moysklad_success")
        flash_type = :notice
      else
        flash_message = result.to_s
        flash_type = :alert
      end
    end

    respond_to do |format|
      format.turbo_stream do
        flash.now[flash_type] = flash_message
        render turbo_stream: [render_turbo_flash]
      end
      format.html { redirect_to products_path, flash_type => flash_message }
    end
  end

  def edit_status_inline; end

  def update_status_inline
    @product.update(status: params[:product][:status])
    flash.now[:success] = t(".success")
    respond_to do |format|
      format.turbo_stream { 
        render turbo_stream: [
          turbo_stream.replace(dom_id(@product), partial: "products/product", locals: { product: @product }),
          render_turbo_flash
        ] 
      # redirect_to products_path(format: :html), notice: t(".success") 
      }
    end
  end

  private

  def set_product
    @product = Product.includes(
      images: [:file_attachment, :file_blob],
      variants: [],
      features: { property: :characteristics }
    ).find(params[:id])
  end

  def clear_preloaded_detals
    Variant.clear_preloaded_detals
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
      features_attributes: [:id, :property_id, :characteristic_id, :_destroy],
      images_attributes: [:id, :product_id, :position, :file, :_destroy],
      variants_attributes: [:id, :product_id, :sku, :barcode, :quantity, :cost_price, :price, :_destroy]
    )
  end

end
