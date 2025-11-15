class VarbindsController < ApplicationController
  include ActionView::RecordIdentifier
  before_action :set_record
  before_action :set_varbind, only: [:edit, :update, :destroy]

  def index
    if @record
      @varbinds = @record.bindings
    else
      @varbinds = Varbind.all
    end
  end

  def new
    @varbind = @record.bindings.build
  end

  def create
    @varbind = @record.bindings.build(varbind_params)
    respond_to do |format|
      if @varbind.save
        format.turbo_stream do          
          render turbo_stream: [
            turbo_stream.append(
              dom_id(@record, :bindings),
              partial: "varbinds/varbind",
              locals: { varbind: @varbind, record: @record }
            ),
            turbo_stream.update(
              dom_id(@record, dom_id(Varbind.new)),
              html: ""
            )
          ]
        end
        format.html { redirect_to @record.bindings_path, notice: 'Varbind created.' }
      else
        format.html { render :new, status: :unprocessable_entity }
      end
    end
  end

  def edit; end

  def update
    respond_to do |format|
      if @varbind.update(varbind_params)
        format.turbo_stream do          
          render turbo_stream: [
            turbo_stream.replace(
              dom_id(@record, dom_id(@varbind)),
              partial: "varbinds/varbind",
              locals: { varbind: @varbind, record: @record }
            )
          ]
        end
        format.html { redirect_to @record.bindings_path, notice: 'Varbind updated.' }
      else
        format.html { render :edit, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @varbind.destroy
    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(dom_id(@record, dom_id(@varbind)))
        ]
      end
      format.html { redirect_to @record.bindings_path, notice: 'Varbind deleted.' }
    end
  end

  private

  def set_record
    @record = if params[:product_id]
      Product.find_by(id: params[:product_id])
    elsif params[:variant_id]
      Variant.find_by(id: params[:variant_id])
    elsif params[:id]
      # Fallback for non-nested routes: infer parent from varbind
      Varbind.find_by(id: params[:id])&.record
    end
  end

  def set_varbind
    @varbind = if @record
      @record.bindings.find(params[:id])
    else
      Varbind.find(params[:id])
    end
  end

  def varbind_params
    params.require(:varbind).permit(:bindable_type, :bindable_id, :value)
  end
end