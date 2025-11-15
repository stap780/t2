class DeleteImageByBlobSignedIdJob < ApplicationJob
  queue_as :image

  def perform(blob_signed_ids, current_user_id)
    blob_signed_ids.each do |blob_signed_id|
      blob = ActiveStorage::Blob.find_signed(blob_signed_id)
      success = DeleteImageByBlob.new(blob).call
      if success
        Turbo::StreamsChannel.broadcast_remove_to(
          'images',
          target: blob_signed_id
        )
      end
    end
  end
end
