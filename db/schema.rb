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

ActiveRecord::Schema[8.0].define(version: 2025_11_07_094609) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
    t.index ["active_job_id"], name: "index_exports_on_active_job_id"
    t.index ["exported_at"], name: "index_exports_on_exported_at"
    t.index ["format"], name: "index_exports_on_format"
    t.index ["scheduled_for"], name: "index_exports_on_scheduled_for"
    t.index ["status"], name: "index_exports_on_status"
    t.index ["user_id", "created_at"], name: "index_exports_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_exports_on_user_id"
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

  create_table "insales", force: :cascade do |t|
    t.string "api_key"
    t.string "api_password"
    t.string "api_link"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
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
    t.string "role", default: "user", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["role"], name: "index_users_on_role"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "exports", "users"
  add_foreign_key "import_schedules", "users"
  add_foreign_key "imports", "users"
  add_foreign_key "sessions", "users"
end
