Rails.configuration.to_prepare do
    ActiveStorage::Attachment.audited associated_with: :record
    ActionText::RichText.audited associated_with: :record
    
    # Audited по умолчанию использует метод current_user из ApplicationController
    # который возвращает Current.user
end