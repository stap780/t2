# frozen_string_literal: true

class InsalesOrderImportJob < ApplicationJob
  queue_as :default

  def perform(insale_id, payload)
    insale = Insale.find(insale_id)
    Insales::Orders::ProcessWebhook.call(insale: insale, payload: payload)
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error "[InsalesOrderImportJob] #{e.message}"
  end
end
