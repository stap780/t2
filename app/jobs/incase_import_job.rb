class IncaseImportJob < ApplicationJob
  queue_as :default
  
  def perform(incase_import_id)
    incase_import = IncaseImport.find(incase_import_id)
    IncaseService.new(incase_import).call
  end
end

