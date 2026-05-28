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

ActiveRecord::Schema[8.1].define(version: 2026_05_27_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "act_items", force: :cascade do |t|
    t.bigint "act_id", null: false
    t.datetime "created_at", null: false
    t.bigint "item_id", null: false
    t.datetime "updated_at", null: false
    t.index ["act_id", "item_id"], name: "index_act_items_on_act_id_and_item_id", unique: true
    t.index ["act_id"], name: "index_act_items_on_act_id"
    t.index ["item_id"], name: "index_act_items_on_item_id"
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "acts", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.date "date"
    t.bigint "driver_id"
    t.string "number"
    t.bigint "okrug_id", null: false
    t.string "status", default: "pending"
    t.bigint "strah_id", null: false
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_acts_on_company_id"
    t.index ["date"], name: "index_acts_on_date"
    t.index ["driver_id"], name: "index_acts_on_driver_id"
    t.index ["number"], name: "index_acts_on_number"
    t.index ["okrug_id"], name: "index_acts_on_okrug_id"
    t.index ["status"], name: "index_acts_on_status"
    t.index ["strah_id"], name: "index_acts_on_strah_id"
  end

  create_table "ar_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "data"
    t.string "session_id", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_ar_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_ar_sessions_on_updated_at"
  end

  create_table "audits", force: :cascade do |t|
    t.string "action"
    t.integer "associated_id"
    t.string "associated_type"
    t.integer "auditable_id"
    t.string "auditable_type"
    t.jsonb "audited_changes"
    t.string "comment"
    t.datetime "created_at"
    t.string "remote_address"
    t.string "request_uuid"
    t.integer "user_id"
    t.string "user_type"
    t.string "username"
    t.integer "version", default: 0
    t.index ["associated_type", "associated_id"], name: "associated_index"
    t.index ["auditable_type", "auditable_id", "version"], name: "auditable_index"
    t.index ["created_at"], name: "index_audits_on_created_at"
    t.index ["request_uuid"], name: "index_audits_on_request_uuid"
    t.index ["user_id", "user_type"], name: "user_index"
  end

  create_table "avito_order_status_mappings", force: :cascade do |t|
    t.bigint "avito_id", null: false
    t.string "avito_status", null: false
    t.datetime "created_at", null: false
    t.bigint "order_status_id", null: false
    t.datetime "updated_at", null: false
    t.index ["avito_id", "order_status_id"], name: "index_avito_order_status_mappings_on_avito_and_order_status", unique: true
    t.index ["avito_id"], name: "index_avito_order_status_mappings_on_avito_id"
  end

  create_table "avitos", force: :cascade do |t|
    t.string "api_id"
    t.string "api_secret"
    t.datetime "created_at", null: false
    t.integer "profileid"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["api_id"], name: "index_avitos_on_api_id", unique: true
    t.index ["api_secret"], name: "index_avitos_on_api_secret", unique: true
  end

  create_table "barcode_counters", force: :cascade do |t|
    t.integer "last_value", default: 900000, null: false
  end

  create_table "characteristics", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "property_id", null: false
    t.string "title", null: false
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
    t.datetime "created_at", null: false
    t.string "email"
    t.string "middlename"
    t.string "name"
    t.string "phone"
    t.string "surname"
    t.datetime "updated_at", null: false
  end

  create_table "comments", force: :cascade do |t|
    t.text "body"
    t.integer "commentable_id"
    t.string "commentable_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["commentable_type", "commentable_id"], name: "index_comments_on_commentable_type_and_commentable_id"
    t.index ["user_id"], name: "index_comments_on_user_id"
  end

  create_table "companies", force: :cascade do |t|
    t.string "bank_account"
    t.string "bank_title"
    t.string "bik"
    t.datetime "created_at", null: false
    t.string "fact_address"
    t.text "info"
    t.string "inn"
    t.string "kpp"
    t.string "ogrn"
    t.string "okpo"
    t.integer "okrug_id"
    t.decimal "rate", precision: 5, scale: 2, default: "100.0"
    t.string "short_title"
    t.string "tip"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "ur_address"
    t.jsonb "weekdays", default: []
    t.index ["short_title"], name: "index_companies_on_short_title"
    t.index ["tip"], name: "index_companies_on_tip"
    t.index ["weekdays"], name: "index_companies_on_weekdays", using: :gin
  end

  create_table "company_plan_dates", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "date"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_company_plan_dates_on_company_id"
  end

  create_table "dashboards", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "departments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_departments_on_name"
  end

  create_table "detals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "desc"
    t.decimal "oszz_price", precision: 12, scale: 2, default: "0.0"
    t.string "sku"
    t.boolean "status"
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "email_deliveries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "job_id"
    t.string "mailer_class", null: false
    t.string "mailer_method", null: false
    t.jsonb "metadata"
    t.text "recipient_email", null: false
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.bigint "record_id"
    t.string "record_type"
    t.datetime "sent_at"
    t.string "status", default: "pending", null: false
    t.text "subject"
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_email_deliveries_on_job_id"
    t.index ["recipient_type", "recipient_id"], name: "index_email_deliveries_on_recipient"
    t.index ["recipient_type", "recipient_id"], name: "index_email_deliveries_on_recipient_type_and_recipient_id"
    t.index ["record_type", "record_id"], name: "index_email_deliveries_on_record"
    t.index ["record_type", "record_id"], name: "index_email_deliveries_on_record_type_and_record_id"
    t.index ["status"], name: "index_email_deliveries_on_status"
  end

  create_table "employees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "department_id"
    t.string "full_name", null: false
    t.bigint "manager_id"
    t.integer "position", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["full_name"], name: "index_employees_on_full_name"
    t.index ["manager_id"], name: "index_employees_on_manager_id"
    t.index ["position"], name: "index_employees_on_position", unique: true
    t.index ["user_id"], name: "index_employees_on_user_id"
  end

  create_table "export_filter_rules", force: :cascade do |t|
    t.bigint "characteristic_id"
    t.datetime "created_at", null: false
    t.bigint "export_id", null: false
    t.integer "position", default: 0, null: false
    t.bigint "property_id"
    t.string "rule_condition", null: false
    t.string "rule_key", null: false
    t.text "rule_value"
    t.datetime "updated_at", null: false
    t.index ["export_id", "position"], name: "index_export_filter_rules_on_export_id_and_position"
    t.index ["export_id"], name: "index_export_filter_rules_on_export_id"
  end

  create_table "exports", force: :cascade do |t|
    t.string "active_job_id"
    t.datetime "created_at", null: false
    t.string "error_message"
    t.datetime "exported_at"
    t.string "file_headers"
    t.string "format", default: "csv", null: false
    t.integer "interval_hours"
    t.text "item_template"
    t.text "layout_template"
    t.string "name", null: false
    t.datetime "scheduled_for"
    t.string "status", default: "pending", null: false
    t.text "template"
    t.boolean "test", default: false
    t.string "time"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["active_job_id"], name: "index_exports_on_active_job_id"
    t.index ["exported_at"], name: "index_exports_on_exported_at"
    t.index ["format"], name: "index_exports_on_format"
    t.index ["scheduled_for"], name: "index_exports_on_scheduled_for"
    t.index ["status"], name: "index_exports_on_status"
    t.index ["user_id", "created_at"], name: "index_exports_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_exports_on_user_id"
  end

  create_table "features", force: :cascade do |t|
    t.bigint "characteristic_id", null: false
    t.datetime "created_at", null: false
    t.bigint "featureable_id", null: false
    t.string "featureable_type", null: false
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["characteristic_id"], name: "index_features_on_characteristic_id"
    t.index ["featureable_type", "featureable_id", "property_id"], name: "index_features_on_featureable_and_property", unique: true
    t.index ["featureable_type", "featureable_id"], name: "index_features_on_featureable"
    t.index ["property_id"], name: "index_features_on_property_id"
  end

  create_table "images", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position"
    t.bigint "product_id", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_images_on_position"
    t.index ["product_id"], name: "index_images_on_product_id"
    t.unique_constraint ["product_id", "position"], deferrable: :deferred, name: "unique_product_id_position"
  end

  create_table "import_schedules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "active_job_id"
    t.datetime "created_at", null: false
    t.string "name"
    t.string "recurrence", default: "daily", null: false
    t.datetime "scheduled_for"
    t.string "time", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["active_job_id"], name: "index_import_schedules_on_active_job_id"
    t.index ["scheduled_for"], name: "index_import_schedules_on_scheduled_for"
    t.index ["user_id"], name: "index_import_schedules_on_user_id"
  end

  create_table "imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.string "file_header"
    t.datetime "imported_at"
    t.string "name", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["imported_at"], name: "index_imports_on_imported_at"
    t.index ["status"], name: "index_imports_on_status"
    t.index ["user_id"], name: "index_imports_on_user_id"
  end

  create_table "incase_dubls", force: :cascade do |t|
    t.string "carnumber"
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.datetime "date"
    t.bigint "incase_import_id", null: false
    t.string "modelauto"
    t.string "region"
    t.string "stoanumber"
    t.integer "strah_id"
    t.decimal "totalsum"
    t.string "unumber"
    t.datetime "updated_at", null: false
    t.index ["incase_import_id"], name: "index_incase_dubls_on_incase_import_id"
    t.index ["unumber", "stoanumber"], name: "index_incase_dubls_on_unumber_and_stoanumber"
    t.index ["unumber"], name: "index_incase_dubls_on_unumber"
  end

  create_table "incase_imports", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.integer "failed_count", default: 0
    t.jsonb "import_errors", default: []
    t.datetime "imported_at"
    t.string "status", default: "pending", null: false
    t.integer "success_count", default: 0
    t.integer "total_rows", default: 0
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["created_at"], name: "index_incase_imports_on_created_at"
    t.index ["status"], name: "index_incase_imports_on_status"
    t.index ["user_id"], name: "index_incase_imports_on_user_id"
  end

  create_table "incase_item_dubls", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "incase_dubl_id", null: false
    t.string "katnumber"
    t.decimal "price", precision: 12, scale: 2, default: "0.0"
    t.integer "quantity"
    t.string "supplier_code"
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["incase_dubl_id"], name: "index_incase_item_dubls_on_incase_dubl_id"
  end

  create_table "incase_statuses", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "position", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "incase_tips", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "position", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "incases", force: :cascade do |t|
    t.string "carnumber"
    t.integer "company_id"
    t.datetime "created_at", null: false
    t.datetime "date"
    t.integer "incase_status_id"
    t.integer "incase_tip_id"
    t.string "modelauto"
    t.string "region"
    t.boolean "sendstatus"
    t.string "stoanumber"
    t.integer "strah_id"
    t.decimal "totalsum", precision: 12, scale: 2, default: "0.0"
    t.string "unumber"
    t.datetime "updated_at", null: false
    t.index ["company_id"], name: "index_incases_on_company_id"
    t.index ["sendstatus"], name: "index_incases_on_sendstatus"
    t.index ["strah_id"], name: "index_incases_on_strah_id"
  end

  create_table "insales", force: :cascade do |t|
    t.string "api_key"
    t.string "api_link"
    t.string "api_password"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "insales_order_field_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "insale_id", null: false
    t.string "insales_field_handle"
    t.integer "insales_field_id"
    t.string "insales_field_title"
    t.string "source_key", null: false
    t.datetime "updated_at", null: false
    t.index ["insale_id", "source_key"], name: "index_insales_order_field_mappings_on_insale_and_source", unique: true
    t.index ["insale_id"], name: "index_insales_order_field_mappings_on_insale_id"
  end

  create_table "insales_order_status_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "insale_id", null: false
    t.string "insales_custom_status_permalink", null: false
    t.string "insales_financial_status", default: "pending", null: false
    t.bigint "order_status_id", null: false
    t.datetime "updated_at", null: false
    t.index ["insale_id", "insales_custom_status_permalink", "insales_financial_status"], name: "index_insales_order_status_mappings_unique", unique: true
    t.index ["insale_id"], name: "index_insales_order_status_mappings_on_insale_id"
    t.index ["order_status_id"], name: "index_insales_order_status_mappings_on_order_status_id"
  end

  create_table "item_statuses", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.integer "position", default: 1, null: false
    t.string "title"
    t.datetime "updated_at", null: false
  end

  create_table "items", force: :cascade do |t|
    t.string "condition"
    t.datetime "created_at", null: false
    t.integer "incase_id"
    t.integer "item_status_id"
    t.string "katnumber"
    t.decimal "price", precision: 12, scale: 2, default: "0.0"
    t.integer "quantity"
    t.decimal "sum", precision: 12, scale: 2, default: "0.0"
    t.string "supplier_code"
    t.string "title"
    t.datetime "updated_at", null: false
    t.integer "variant_id"
    t.integer "vat"
    t.index ["condition"], name: "index_items_on_condition"
    t.index ["incase_id"], name: "index_items_on_incase_id"
    t.index ["variant_id"], name: "index_items_on_variant_id"
  end

  create_table "moysklad_order_field_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "moysklad_id", null: false
    t.string "ms_attribute_href", null: false
    t.string "ms_attribute_name"
    t.string "source_key", null: false
    t.datetime "updated_at", null: false
    t.index ["moysklad_id", "source_key"], name: "index_ms_order_field_mappings_on_moysklad_and_source", unique: true
    t.index ["moysklad_id"], name: "index_moysklad_order_field_mappings_on_moysklad_id"
  end

  create_table "moysklad_order_status_mappings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "moysklad_state_href", null: false
    t.string "moysklad_state_name"
    t.bigint "order_status_id", null: false
    t.datetime "updated_at", null: false
    t.index ["moysklad_state_href"], name: "index_moysklad_order_status_mappings_on_moysklad_state_href", unique: true
    t.index ["order_status_id"], name: "index_moysklad_order_status_mappings_on_order_status_id"
  end

  create_table "moysklads", force: :cascade do |t|
    t.string "agent_href"
    t.string "api_key"
    t.string "api_password"
    t.datetime "created_at", null: false
    t.string "default_ad_source_href"
    t.string "default_ad_source_name"
    t.string "order_number_prefix"
    t.datetime "orders_integration_start_at"
    t.string "organization_href"
    t.string "store_href"
    t.datetime "updated_at", null: false
  end

  create_table "okrugs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "position", default: 1
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["title"], name: "index_okrugs_on_title", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "order_id", null: false
    t.decimal "price", precision: 12, scale: 2
    t.integer "quantity", default: 1, null: false
    t.string "sku"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "variant_id"
    t.integer "vat", default: 0, null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["variant_id"], name: "index_order_items_on_variant_id"
  end

  create_table "order_statuses", force: :cascade do |t|
    t.string "code", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.boolean "is_terminal", default: false, null: false
    t.integer "position", default: 1, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_order_statuses_on_code", unique: true
    t.index ["position"], name: "index_order_statuses_on_position"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "avito_id"
    t.string "avito_marketplace_id"
    t.string "avito_order_id"
    t.string "avito_status_sent"
    t.bigint "client_id"
    t.datetime "created_at", null: false
    t.string "currency", default: "RUB", null: false
    t.bigint "insale_id"
    t.string "insales_order_id"
    t.string "last_moysklad_state_href"
    t.string "moysklad_external_code"
    t.string "moysklad_order_id"
    t.string "number"
    t.bigint "order_status_id"
    t.string "source", null: false
    t.datetime "synced_at"
    t.decimal "total_sum", precision: 12, scale: 2
    t.string "tracking_number"
    t.datetime "updated_at", null: false
    t.index ["avito_id", "avito_marketplace_id"], name: "index_orders_on_avito_id_and_marketplace_id", unique: true, where: "(avito_marketplace_id IS NOT NULL)"
    t.index ["avito_id", "avito_order_id"], name: "index_orders_on_avito_id_and_avito_order_id", unique: true, where: "(avito_order_id IS NOT NULL)"
    t.index ["avito_id"], name: "index_orders_on_avito_id"
    t.index ["client_id"], name: "index_orders_on_client_id"
    t.index ["insale_id", "insales_order_id"], name: "index_orders_on_insale_id_and_insales_order_id", unique: true, where: "(insales_order_id IS NOT NULL)"
    t.index ["insale_id"], name: "index_orders_on_insale_id"
    t.index ["moysklad_order_id"], name: "index_orders_on_moysklad_order_id", unique: true, where: "(moysklad_order_id IS NOT NULL)"
    t.index ["number"], name: "index_orders_on_number"
    t.index ["order_status_id"], name: "index_orders_on_order_status_id"
    t.index ["source"], name: "index_orders_on_source"
  end

  create_table "products", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "status", default: "draft"
    t.string "tip", default: "product"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_products_on_status"
    t.index ["title"], name: "index_products_on_title"
  end

  create_table "properties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "handle"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["handle"], name: "index_properties_on_handle", unique: true
    t.index ["title"], name: "index_properties_on_title", unique: true
  end

  create_table "schedule_days", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "employee_id", null: false
    t.bigint "shift_code_id", null: false
    t.datetime "updated_at", null: false
    t.date "worked_on", null: false
    t.index ["employee_id", "worked_on"], name: "index_schedule_days_on_employee_id_and_worked_on", unique: true
    t.index ["employee_id"], name: "index_schedule_days_on_employee_id"
    t.index ["shift_code_id"], name: "index_schedule_days_on_shift_code_id"
    t.index ["worked_on"], name: "index_schedule_days_on_worked_on"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "shift_codes", force: :cascade do |t|
    t.string "code", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.boolean "day_off", default: false, null: false
    t.string "label", null: false
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.boolean "vacation", default: false, null: false
    t.index ["code"], name: "index_shift_codes_on_code", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name"
    t.string "password_digest", null: false
    t.string "role"
    t.string "surname"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "varbinds", force: :cascade do |t|
    t.bigint "bindable_id", null: false
    t.string "bindable_type", null: false
    t.datetime "created_at", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.datetime "updated_at", null: false
    t.string "value", null: false
    t.index ["bindable_type", "bindable_id", "record_type", "record_id", "value"], name: "index_bindings_on_bindable_record_and_value", unique: true
    t.index ["record_type", "record_id", "bindable_type", "bindable_id"], name: "index_varbinds_on_record_and_bindable_unique", unique: true
    t.index ["record_type", "record_id"], name: "index_varbinds_on_record_type_and_record_id"
    t.index ["value"], name: "index_varbinds_on_value"
  end

  create_table "variants", force: :cascade do |t|
    t.string "barcode"
    t.decimal "cost_price", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.decimal "price", precision: 12, scale: 2
    t.bigint "product_id", null: false
    t.integer "quantity"
    t.string "sku"
    t.decimal "sprice", precision: 12, scale: 2
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
  add_foreign_key "avito_order_status_mappings", "avitos"
  add_foreign_key "avito_order_status_mappings", "order_statuses"
  add_foreign_key "characteristics", "properties"
  add_foreign_key "client_companies", "clients"
  add_foreign_key "client_companies", "companies"
  add_foreign_key "company_plan_dates", "companies"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "employees", column: "manager_id"
  add_foreign_key "employees", "users"
  add_foreign_key "export_filter_rules", "exports"
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
  add_foreign_key "insales_order_field_mappings", "insales"
  add_foreign_key "insales_order_status_mappings", "insales"
  add_foreign_key "insales_order_status_mappings", "order_statuses"
  add_foreign_key "items", "incases"
  add_foreign_key "items", "variants"
  add_foreign_key "moysklad_order_field_mappings", "moysklads"
  add_foreign_key "moysklad_order_status_mappings", "order_statuses"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "variants"
  add_foreign_key "orders", "avitos"
  add_foreign_key "orders", "clients"
  add_foreign_key "orders", "insales"
  add_foreign_key "orders", "order_statuses"
  add_foreign_key "schedule_days", "employees"
  add_foreign_key "schedule_days", "shift_codes"
  add_foreign_key "sessions", "users"
  add_foreign_key "variants", "products"
end
