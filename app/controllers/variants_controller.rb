class VariantsController < ApplicationController
  before_action :set_product
  before_action :set_variant, only: %i[show edit update destroy print_etiketka edit_price_inline update_price_inline]
  include ActionView::RecordIdentifier

  def index
    @variants = @product.variants.order(:id)
  end

  def show; end

  def new
    @variant = @product.variants.build
  end

  def edit; end

  def create
    @variant = @product.variants.build(variant_params)

    respond_to do |format|
      if @variant.save
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.append(
              dom_id(@product, :variants),
              partial: "variants/variant",
              locals: { variant: @variant, product: @product }
            )
          ]
        end
        format.html { redirect_to product_variant_url(@product, @variant), notice: t('.success') }
        format.json { render :show, status: :created, location: @variant }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @variant.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    respond_to do |format|
      if @variant.update(variant_params)
        flash.now[:success] = t('.success')
        format.turbo_stream do
          render turbo_stream: turbo_close_offcanvas_flash + [
            turbo_stream.replace(
              dom_id(@product, dom_id(@variant)),
              partial: "variants/variant",
              locals: { variant: @variant, product: @product }
            )
          ]
        end
        format.html { redirect_to product_variant_url(@product, @variant), notice: t('.success') }
        format.json { render :show, status: :ok, location: @variant }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @variant.errors, status: :unprocessable_entity }
      end
    end
  end

  def edit_price_inline; end

  def update_price_inline
    respond_to do |format|
      if @variant.update(variant_params)
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.replace(dom_id(@product, dom_id(@variant, :price)), partial: "products/inline/price", locals: { product: @product, variant: @variant })
          ]
        end
      end
    end
  end
  
  def print_etiketka
    # Если этикетка уже существует, используем её
    if @variant.etiketka.attached?
      redirect_to rails_blob_path(@variant.etiketka, disposition: 'inline'), allow_other_host: false
    else
      # Если этикетки нет, генерируем её
      @variant.generate_etiketka
      
      if @variant.etiketka.attached?
        redirect_to rails_blob_path(@variant.etiketka, disposition: 'inline'), allow_other_host: false
      else
        flash[:alert] = "Не удалось сгенерировать этикетку. Убедитесь, что у варианта есть штрих-код."
        redirect_back(fallback_location: product_variants_path(@product))
      end
    end
  rescue => e
    Rails.logger.error "VariantsController#print_etiketka error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    flash[:alert] = "Ошибка при открытии этикетки: #{e.message}"
    redirect_back(fallback_location: product_variants_path(@product))
  end

  def destroy
    check_destroy = @variant.destroy ? true : false
    if check_destroy == true
      flash.now[:success] = t('.success')
    else
      flash.now[:notice] = @variant.errors.full_messages.join(' ')
    end
    respond_to do |format|
      format.turbo_stream do
        if check_destroy == true
          render turbo_stream: [
            turbo_stream.remove(dom_id(@product, dom_id(@variant))),
            render_turbo_flash
          ]
        else
          render turbo_stream: [
            render_turbo_flash
          ]
        end
      end
      format.html { redirect_to product_variants_path(@product), notice: t('.success') }
      format.json { head :no_content }
    end
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def set_variant
    @variant = @product.variants.find(params[:id])
  end

  def variant_params
    params.require(:variant).permit(:product_id, :sku, :barcode, :quantity, :cost_price, :price)
  end

  def render_turbo_flash
    turbo_stream.replace("flash", partial: "shared/flash")
  end
end
