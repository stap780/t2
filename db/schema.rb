# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_10_180000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "act_items", force: :cascade do |t|
    t.bigint "act_id", null: false
    t.bigint "item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["act_id", "item_id"], name: "index_act_items_on_act_id_and_item_id", unique: true
    t.index ["act_id"], name: "index_act_items_on_act_id"
    t.index ["item_id"], name: "index_act_items_on_item_id"
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "acts", force: :cascade do |t|
    t.string "number"
    t.date "date"
    t.string "status", default: "pending"
    t.bigint "company_id", null: false
    t.bigint "strah_id", null: false
    t.bigint "okrug_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "driver_id"
    t.index ["company_id"], name: "index_acts_on_company_id"
    t.index ["date"], name: "index_acts_on_date"
    t.index ["driver_id"], name: "index_acts_on_driver_id"
    t.index ["number"], name: "index_acts_on_number"
    t.index ["okrug_id"], name: "index_acts_on_okrug_id"
    t.index ["status"], name: "index_acts_on_status"
    t.index ["strah_id"], name: "index_acts_on_strah_id"
  end

  create_table "ar_sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_ar_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_ar_sessions_on_updated_at"
  end

  create_table "audits", force: :cascade do |t|
    t.integer "auditable_id"
    t.string "auditable_type"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.string "action"
    t.jsonb "audited_changes"
    t.integer "version", default: 0
    t.string "comment"
    t.string "remote_address"
    t.string "request_uuid"
    t.datetime "created_at"
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "characteristics", force: :cascade do |t|
    t.bigint "property_id", null: false
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id", "title"], name: "index_characteristics_on_property_and_title", unique: true
    t.index ["property_id"], name: "index_characteristics_on_property_id"
  end

  create_table "client_companies", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_client_companies_on_client_id"
    t.index ["company_id"], name: "index_client_companies_on_company_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "surname"
    t.string "name"
    t.string "middlename"
    t.string "phone"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "comments", force: :cascade do |t|
    t.string "commentable_type"
    t.integer "commentable_id"
    t.integer "user_id"
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "inn"
    t.string "kpp"
    t.string "title"
    t.string "short_title"
    t.string "ur_address"
    t.string "fact_address"
    t.string "ogrn"
    t.string "okpo"
    t.string "bik"
    t.string "bank_title"
    t.string "bank_account"
    t.string "tip"
    t.integer "okrug_id"
    t.text "info"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "weekdays", default: []
    t.decimal "rate", precision: 5, scale: 2, default: "100.0"
    t.index ["short_title"], name: "index_companies_on_short_title"
    t.index ["tip"], name: "index_companies_on_tip"
    t.index ["weekdays"], name: "index_companies_on_weekdays", using: :gin
  end

  create_table "company_plan_dates", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_plan_dates_on_company_id"
  end

  create_table "dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "detals", force: :cascade do |t|
    t.boolean "status"
    t.string "sku"
    t.string "title"
    t.text "desc"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "oszz_price", precision: 12, scale: 2, default: "0.0"
  end

  create_table "email_deliveries", force: :cascade do |t|
    t.string "recipient_type", null: false
    t.bigint "recipient_id", null: false
    t.string "record_type"
    t.bigint "record_id"
    t.string "mailer_class", null: false
    t.string "mailer_method", null: false
    t.string "status", default: "pending", null: false
    t.text "error_message"
    t.text "recipient_email", null: false
    t.text "subject"
    t.string "job_id"
    t.datetime "sent_at"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_email_deliveries_on_job_id"
    t.index ["recipient_type", "recipient_id"], name: "index_email_deliveries_on_recipient"
    t.index ["recipient_type", "recipient_id"], name: "index_email_deliveries_on_recipient_type_and_recipient_id"
    t.index ["record_type", "record_id"], name: "index_email_deliveries_on_record"
    t.index ["record_type", "record_id"], name: "index_email_deliveries_on_record_type_and_record_id"
    t.index ["status"], name: "index_email_deliveries_on_status"
  end

  create_table "exports", force: :cascade do |t|
    t.string "name", null: false
    t.string "format", default: "csv", null: false
    t.string "status", default: "pending", null: false
    t.text "template"
    t.datetime "exported_at"
    t.string "error_message"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "test", default: false
    t.string "file_headers"
    t.string "time"
    t.datetime "scheduled_for"
    t.string "active_job_id"
    t.text "layout_template"
    t.text "item_template"
    t.index ["active_job_id"], name: "index_exports_on_active_job_id"
    t.index ["exported_at"], name: "index_exports_on_exported_at"
    t.index ["format"], name: "index_exports_on_format"
    t.index ["scheduled_for"], name: "index_exports_on_scheduled_for"
    t.index ["status"], name: "index_exports_on_status"
    t.index ["user_id", "created_at"], name: "index_exports_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_exports_on_user_id"
  end

  create_table "features", force: :cascade do |t|
    t.bigint "property_id", null: false
    t.bigint "characteristic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "featureable_type", null: false
    t.bigint "featureable_id", null: false
    t.index ["characteristic_id"], name: "index_features_on_characteristic_id"
    t.index ["featureable_type", "featureable_id", "property_id"], name: "index_features_on_featureable_and_property", unique: true
    t.index ["featureable_type", "featureable_id"], name: "index_features_on_featureable"
    t.index ["property_id"], name: "index_features_on_property_id"
  end

  create_table "images", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_images_on_position"
    t.index ["product_id"], name: "index_images_on_product_id"
    t.unique_constraint ["product_id", "position"], deferrable: :deferred, name: "unique_product_id_position"
  end

  create_table "import_schedules", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "time", null: false
    t.string "recurrence", default: "daily", null: false
    t.datetime "scheduled_for"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "active_job_id"
    t.index ["active_job_id"], name: "index_import_schedules_on_active_job_id"
    t.index ["scheduled_for"], name: "index_import_schedules_on_scheduled_for"
    t.index ["user_id"], name: "index_import_schedules_on_user_id"
  end

  create_table "imports", force: :cascade do |t|
    t.string "name", null: false
    t.string "status", default: "pending", null: false
    t.datetime "imported_at"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "error_message"
    t.string "file_header"
    t.index ["imported_at"], name: "index_imports_on_imported_at"
    t.index ["status"], name: "index_imports_on_status"
    t.index ["user_id"], name: "index_imports_on_user_id"
  end

  create_table "incase_dubls", force: :cascade do |t|
    t.string "region"
    t.integer "strah_id"
    t.string "stoanumber"
    t.string "unumber"
    t.integer "company_id"
    t.string "carnumber"
    t.datetime "date"
    t.string "modelauto"
    t.decimal "totalsum"
    t.bigint "incase_import_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incase_import_id"], name: "index_incase_dubls_on_incase_import_id"
    t.index ["unumber", "stoanumber"], name: "index_incase_dubls_on_unumber_and_stoanumber"
    t.index ["unumber"], name: "index_incase_dubls_on_unumber"
  end

  create_table "incase_imports", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "status", default: "pending", null: false
    t.text "error_message"
    t.jsonb "import_errors", default: []
    t.integer "success_count", default: 0
    t.integer "failed_count", default: 0
    t.integer "total_rows", default: 0
    t.datetime "imported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_incase_imports_on_created_at"
    t.index ["status"], name: "index_incase_imports_on_status"
    t.index ["user_id"], name: "index_incase_imports_on_user_id"
  end

  create_table "incase_item_dubls", force: :cascade do |t|
    t.bigint "incase_dubl_id", null: false
    t.string "title"
    t.integer "quantity"
    t.string "katnumber"
    t.decimal "price", precision: 12, scale: 2, default: "0.0"
    t.string "supplier_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["incase_dubl_id"], name: "index_incase_item_dubls_on_incase_dubl_id"
  end

  create_table "incase_statuses", force: :cascade do |t|
    t.string "title"
    t.string "color"
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "incase_tips", force: :cascade do |t|
    t.string "title"
    t.string "color"
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "incases", force: :cascade do |t|
    t.string "region"
    t.integer "strah_id"
    t.string "stoanumber"
    t.string "unumber"
    t.integer "company_id"
    t.string "carnumber"
    t.datetime "date"
    t.string "modelauto"
    t.decimal "totalsum", precision: 12, scale: 2, default: "0.0"
    t.string "incase_status_id"
    t.string "incase_tip_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "sendstatus"
    t.index ["company_id"], name: "index_incases_on_company_id"
    t.index ["sendstatus"], name: "index_incases_on_sendstatus"
    t.index ["strah_id"], name: "index_incases_on_strah_id"
  end

  create_table "insales", force: :cascade do |t|
    t.string "api_key"
    t.string "api_password"
    t.string "api_link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "item_statuses", force: :cascade do |t|
    t.string "title"
    t.string "color"
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "items", force: :cascade do |t|
    t.integer "incase_id"
    t.string "title"
    t.integer "quantity"
    t.string "katnumber"
    t.decimal "price", precision: 12, scale: 2, default: "0.0"
    t.decimal "sum", precision: 12, scale: 2, default: "0.0"
    t.integer "item_status_id"
    t.integer "variant_id"
    t.integer "vat"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "supplier_code"
    t.string "condition"
    t.index ["condition"], name: "index_items_on_condition"
    t.index ["incase_id"], name: "index_items_on_incase_id"
    t.index ["variant_id"], name: "index_items_on_variant_id"
  end

  create_table "moysklads", force: :cascade do |t|
    t.string "api_key"
    t.string "api_password"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "okrugs", force: :cascade do |t|
    t.string "title", null: false
    t.integer "position", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_okrugs_on_title", unique: true
  end

  create_table "products", force: :cascade do |t|
    t.string "status", default: "draft"
    t.string "tip", default: "product"
    t.string "title", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_products_on_status"
    t.index ["title"], name: "index_products_on_title"
  end

  create_table "properties", force: :cascade do |t|
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "handle"
    t.index ["handle"], name: "index_properties_on_handle", unique: true
    t.index ["title"], name: "index_properties_on_title", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "varbinds", force: :cascade do |t|
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.string "bindable_type", null: false
    t.bigint "bindable_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["bindable_type", "bindable_id", "record_type", "record_id", "value"], name: "index_bindings_on_bindable_record_and_value", unique: true
    t.index ["record_type", "record_id"], name: "index_varbinds_on_record_type_and_record_id"
    t.index ["value"], name: "index_varbinds_on_value"
  end

  create_table "variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "barcode"
    t.string "sku"
    t.decimal "price", precision: 12, scale: 2
    t.integer "quantity"
    t.decimal "cost_price", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["barcode"], name: "index_variants_on_barcode"
    t.index ["product_id"], name: "index_variants_on_product_id"
    t.index ["sku"], name: "index_variants_on_sku"
  end

  add_foreign_key "act_items", "acts"
  add_foreign_key "act_items", "items"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "acts", "companies"
  add_foreign_key "acts", "companies", column: "strah_id"
  add_foreign_key "acts", "okrugs"
  add_foreign_key "acts", "users", column: "driver_id"
  add_foreign_key "characteristics", "properties"
  add_foreign_key "client_companies", "clients"
  add_foreign_key "client_companies", "companies"
  add_foreign_key "company_plan_dates", "companies"
  add_foreign_key "exports", "users"
  add_foreign_key "features", "characteristics"
  add_foreign_key "features", "properties"
  add_foreign_key "images", "products"
  add_foreign_key "import_schedules", "users"
  add_foreign_key "imports", "users"
  add_foreign_key "incase_dubls", "incase_imports"
  add_foreign_key "incase_imports", "users"
  add_foreign_key "incase_item_dubls", "incase_dubls"
  add_foreign_key "incases", "companies"
  add_foreign_key "incases", "companies", column: "strah_id"
  add_foreign_key "items", "incases"
  add_foreign_key "items", "variants"
  add_foreign_key "sessions", "users"
  add_foreign_key "variants", "products"
end
