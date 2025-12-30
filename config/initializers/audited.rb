Rails.configuration.to_prepare do
    ActiveStorage::Attachment.audited associated_with: :record
    ActionText::RichText.audited associated_with: :record
end