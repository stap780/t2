class ImagesController < ApplicationController
  before_action :set_image, only: %i[show edit update destroy]

  require "image_processing/vips"
  include Rails.application.routes.url_helpers

  def index
    @search = Image.ransack(params[:q])
    @search.sorts = "id desc" if @search.sorts.empty?
    @images = @search.result(distinct: true).paginate(page: params[:page], per_page: Rails.env.development? ? 30 : 100)
    respond_to do |format|
      format.html
    end
  end

  def show
  end

  def new
    @image = Image.new
  end

  def edit
  end

  def create
    @image = Image.new(image_params)
    respond_to do |format|
      if @image.save
        format.html { redirect_to images_path, notice: 'Image was successfully created.' }
        format.json { render :show, status: :created, location: @product }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @image.errors, status: :unprocessable_entity }
      end
    end
  end

  def upload
    params.require(:blob_signed_id)
    signed_id = params['blob_signed_id']
    upload_blob = ActiveStorage::Blob.find_signed(signed_id)
    filename = upload_blob.filename

    # Сжатие изображения через ImageProcessing::Vips
    file = upload_blob.open do |tempfile|
      ImageProcessing::Vips.source(tempfile.path).saver!(quality: 80)
    end

    new_blob = ActiveStorage::Blob.create_and_upload!(io: file, filename: filename)
    @blob = new_blob
    @product_id = params[:product_id]

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = t('.success') }
    end
  end

  def delete
    if params[:blob_signed_ids]
      DeleteImageByBlobSignedIdJob.perform_now(params[:blob_signed_ids], Current.user&.id)
      respond_to do |format|
        format.turbo_stream { flash.now[:success] = t('.success') }
      end
    else
      respond_to do |format|
        format.turbo_stream { flash.now[:success] = 'Please choose images to delete' }
      end
    end
  end

  def update
    respond_to do |format|
      if @image.update(image_params)
        format.html { redirect_to @image, notice: "Image was successfully updated.", status: :see_other }
        format.json { render :show, status: :ok, location: @image }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @image.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @image.destroy
    respond_to do |format|
      format.html { redirect_to images_url, notice: t(".success") }
      format.json { head :no_content }
    end
  end

  private

  def set_image
    @image = Image.find(params[:id])
  end

  def image_params
    params.require(:image).permit(:file, :position, :product_id)
  end
end
