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

ActiveRecord::Schema[8.0].define(version: 2026_01_18_125838) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "act_items", force: :cascade do |t|
    t.bigint "act_id", null: false
    t.bigint "item_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
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
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
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
  end

  create_table "characteristics", force: :cascade do |t|
    t.bigint "property_id", null: false
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "client_companies", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "company_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
  end

  create_table "company_plan_dates", force: :cascade do |t|
    t.bigint "company_id", null: false
    t.datetime "date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
  end

  create_table "features", force: :cascade do |t|
    t.bigint "property_id", null: false
    t.bigint "characteristic_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "featureable_type", null: false
    t.bigint "featureable_id", null: false
  end

  create_table "images", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "product_id", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "import_schedules", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "user_id", null: false
    t.string "name"
    t.string "time", null: false
    t.string "recurrence", default: "daily", null: false
    t.datetime "scheduled_for"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "active_job_id"
  end

  create_table "imports", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "name", null: false
    t.string "status", default: "pending", null: false
    t.datetime "imported_at"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "error_message"
    t.string "file_header"
  end

  create_table "incase_dubls", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
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
  end

  create_table "incase_imports", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
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
  end

  create_table "incase_item_dubls", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "incase_dubl_id", null: false
    t.string "title"
    t.integer "quantity"
    t.string "katnumber"
    t.decimal "price", precision: 12, scale: 2, default: "0.0"
    t.string "supplier_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "incase_statuses", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "title"
    t.string "color"
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "incase_tips", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "title"
    t.string "color"
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "incases", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
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
  end

  create_table "insales", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "api_key"
    t.string "api_password"
    t.string "api_link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "item_statuses", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "title"
    t.string "color"
    t.integer "position", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "items", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
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
  end

  create_table "moysklads", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "api_key"
    t.string "api_password"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "okrugs", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "title", null: false
    t.integer "position", default: 1
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "products", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "status", default: "draft"
    t.string "tip", default: "product"
    t.string "title", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "properties", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "title", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "handle"
  end

  create_table "sessions", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role"
  end

  create_table "varbinds", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.string "bindable_type", null: false
    t.bigint "bindable_id", null: false
    t.string "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "variants", id: false, force: :cascade do |t|
    t.bigserial "id", null: false
    t.bigint "product_id", null: false
    t.string "barcode"
    t.string "sku"
    t.decimal "price", precision: 12, scale: 2
    t.integer "quantity"
    t.decimal "cost_price", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end
end
