class CreateEmailDeliveries < ActiveRecord::Migration[8.0]
  def change
    create_table :email_deliveries do |t|
      t.references :recipient, polymorphic: true, null: false
      t.references :record, polymorphic: true, null: false
      t.string :mailer_class, null: false
      t.string :mailer_method, null: false
      t.string :status, default: 'pending', null: false
      t.text :error_message
      t.text :recipient_email, null: false
      t.text :subject
      t.string :job_id
      t.datetime :sent_at
      t.jsonb :metadata
      t.timestamps
    end
    
    add_index :email_deliveries, [:record_type, :record_id]
    add_index :email_deliveries, [:recipient_type, :recipient_id]
    add_index :email_deliveries, :status
    add_index :email_deliveries, :job_id
  end
end
