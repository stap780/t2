class ItemsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_incase
  before_action :set_item, only: %i[ show edit update destroy update_variant_fields update_status update_condition]

  def index
    @items = @incase.items.order(:id)
  end

  def show
  end

  def new
    @item = @incase.items.build
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  def edit; end

  def create
    @item = @incase.items.build(item_params)

    respond_to do |format|
      if @item.save
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              'items',
              partial: "items/item",
              locals: { item: @item, incase: @incase }
            )
          ]
        end
        format.html { redirect_to incase_path(@incase), notice: t('.success') }
        format.json { render :show, status: :created, location: @item }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @item.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @item.update(item_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.update(
              dom_id(@item),
              partial: "items/item",
              locals: { item: @item, incase: @incase }
            )
          ]
        end
        format.html { redirect_to incase_path(@incase), notice: t('.success') }
        format.json { render :show, status: :ok, location: @item }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @item.errors, status: :unprocessable_entity }
      end
    end
  end

  def apply_free_text
    turbo_frame_id = params[:turbo_frame_id]
    free_title = params[:title].to_s.strip
    return head :unprocessable_entity if free_title.blank?

    item_id_str = turbo_frame_id.sub("item_", "")
    item_id = item_id_str.to_i if item_id_str.match?(/^\d+$/) && item_id_str.to_i < 2_147_483_647
    @item = item_id ? @incase.items.find_by(id: item_id) : nil
    @item ||= @incase.items.build

    @item.variant_id = nil
    @item.title = free_title
    @item.katnumber = nil
    @item.price = 0.0
    @item.sum = 0.0
    @item.quantity = @item.quantity.presence || 1

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          turbo_frame_id,
          partial: "items/item",
          locals: { item: @item, incase: @incase, turbo_frame_id: turbo_frame_id }
        )
      end
    end
  end

  def update_variant_fields
    turbo_frame_id = params[:turbo_frame_id]
    variant_id = params[:variant_id]

    # Пытаемся найти item (для сохраненных items с числовым ID)
    item_id_str = turbo_frame_id.sub('item_', '')
    item_id = item_id_str.to_i if item_id_str.match?(/^\d+$/) && item_id_str.to_i < 2147483647
    @item = item_id ? @incase.items.find_by(id: item_id) : nil

    # Если item не найден, создаем новый (для новых items с hash ID)
    @item ||= @incase.items.build

    if variant_id.present?
      variant = Variant.find_by(id: variant_id)
      if variant
        @item.variant_id = variant.id
        @item.title = item_id ? @item.title : variant.product.title
        @item.price = variant.price
        @item.quantity = variant.quantity
        @item.katnumber = variant.sku
      end
    end
  
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(turbo_frame_id, partial: "items/item", locals: { item: @item, incase: @incase, turbo_frame_id: turbo_frame_id })
        ]
      end
    end
  end

  def search
    if params[:title].present?
      # var.full_title
      @search_results = Variant.ransack(sku_or_barcode_or_product_title_cont: params[:title]).result
        .limit(30)
        .map { |var| { title: var.item.present? ? var.item.title : var.full_title, id: var.id } }
        .reject(&:blank?)
      render json: @search_results, status: :ok
    else
      render json: [], status: :ok
    end
  end

  def suggest_variants
    for_item_id = params[:for_item_id].to_s
    target = "variant_suggest_#{for_item_id}"
    search_query = params[:title].to_s

    variants = if search_query.blank?
      []
    else
      Variant.ransack(sku_or_barcode_or_product_title_cont: search_query).result
        .includes(:items, :product)
        .limit(30)
    end

    render turbo_stream: turbo_stream.update(
      target,
      partial: "items/variant_suggest_list",
      locals: {
        variants: variants,
        incase: @incase,
        for_item_id: for_item_id,
        search_query: search_query
      }
    )
  end

  def destroy
    check_destroy = @item.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @item.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@item)),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to incase_path(@incase), notice: t(".success") }
      format.json { head :no_content }
    end
  end

  def update_status
    @item.update(item_status_id: params[:item_status_id])
  end

  def bulk_update_status
    item_ids = Array(params[:item_ids]).reject(&:blank?).map(&:to_i)
    item_status_id = params[:item_status_id].presence&.to_i

    if item_ids.empty? || item_status_id.blank?
      flash.now[:notice] = 'Выберите позиции и статус'
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
    else
      items = @incase.items.where(id: item_ids)
      items.each do |item|
        item.update(item_status_id: item_status_id)
      end
    end
  end

  def update_condition
    @item.update(condition: params[:condition])
    @item.variant.product.update(status: 'pending') if @item.variant.product.status == 'draft'
  end

  private

  def set_incase
    if params[:incase_id].present?
      @incase = Incase.find(params[:incase_id])
    else
      # Для новых записей создаем временный объект
      @incase = Incase.new
    end
  end

  def set_item
    @item = @incase.items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @item = Item.new(id: params[:id])
  end

  def item_params
    params.require(:item).permit(:incase_id, :title, :quantity, :katnumber, :supplier_code, :price, :sum, :item_status_id, :variant_id, :vat)
  end
end

