class MakeEmailDeliveryRecordOptional < ActiveRecord::Migration[8.0]
  def change
    change_column_null :email_deliveries, :record_type, true
    change_column_null :email_deliveries, :record_id, true
  end
end
