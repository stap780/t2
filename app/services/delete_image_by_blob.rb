class DeleteImageByBlob
  def initialize(blob, options = {})
    @blob = blob
  end

  def call
    true if delete
  end

  private

  def delete
    image = Image.includes(:file_attachment).where(file_attachment: {blob_id: @blob.id})
    if image.present?
      image.take.destroy
      true
    else
      @blob.purge
      true
    end
  end
end
