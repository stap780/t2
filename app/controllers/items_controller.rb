class ItemsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :set_incase
  before_action :set_item, only: %i[ show edit update destroy update_variant_fields ]

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
        @item.title = variant.product.title
        @item.price = variant.price
        @item.quantity = variant.quantity
        @item.katnumber = variant.sku
      end
    end
  
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(turbo_frame_id, partial: "items/item", locals: { item: @item, incase: @incase })
        ]
      end
    end
  end

  def search
    if params[:title].present?
      @search_results = Variant.ransack(sku_or_barcode_or_product_title_cont: params[:title]).result
        .limit(20)
        .map { |var| { title: var.full_title, id: var.id } }
        .reject(&:blank?)
      render json: @search_results, status: :ok
    else
      render json: [], status: :ok
    end
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

  private

  def set_incase
    if params[:incase_id].present?
      @incase = Incase.find(params[:incase_id])
    else
      # Для новых записей создаем временный объект
      @incase = Incase.new
    end
  end

  # def set_item
  #   item_id = params[:id]
  #   # Для новых записей используем hash ID из turbo_id_for
  #   if item_id.present? && item_id.match?(/^\d+$/) && item_id.to_i < 2147483647
  #     @item = @incase.items.find_by(id: item_id) || Item.new(id: item_id, incase: @incase)
  #   else
  #     # Для новых записей с hash ID создаем новый объект с установленным id
  #     @item = Item.new(incase: @incase)
  #     @item.id = item_id if item_id.present?
  #     # Если id не передан, устанавливаем hash для согласованности
  #     @item.id ||= @item.hash unless @item.persisted?
  #   end
  # rescue ActiveRecord::RecordNotFound
  #   @item = Item.new(incase: @incase)
  #   @item.id = params[:id] if params[:id].present?
  #   @item.id ||= @item.hash unless @item.persisted?
  # end
  def set_item
    @item = @incase.items.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    @item = Item.new(id: params[:id])
  end

  def item_params
    params.require(:item).permit(:incase_id, :title, :quantity, :katnumber, :supplier_code, :price, :sum, :item_status_id, :variant_id, :vat)
  end
end

