class ProductImportJob < ApplicationJob
  queue_as :default
  
  def perform
    Rails.logger.info "📦 ProductImportJob: Starting scheduled product import"
    
    result = Product::Import.new.call
    
    if result[:success]
      Rails.logger.info "📦 ProductImportJob: Import completed. Created: #{result[:created]}, Updated: #{result[:updated]}, Errors: #{result[:errors]}"
    else
      Rails.logger.error "📦 ProductImportJob: Import failed: #{result[:error]}"
    end
    
    result
  rescue => e
    Rails.logger.error "📦 ProductImportJob: Unexpected error: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
  end
end

