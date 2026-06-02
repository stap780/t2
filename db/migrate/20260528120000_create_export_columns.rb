# frozen_string_literal: true

class CreateExportColumns < ActiveRecord::Migration[8.0]
  def up
    create_table :export_columns do |t|
      t.references :export, null: false, foreign_key: true
      t.string :field_key, null: false
      t.string :label

      t.timestamps
    end

    add_index :export_columns, [:export_id, :field_key], unique: true

    migrate_file_headers_to_export_columns
  end

  def down
    drop_table :export_columns
  end

  private

  def migrate_file_headers_to_export_columns
    return unless column_exists?(:exports, :file_headers)

    Export.find_each do |export|
      headers = parse_file_headers(export.read_attribute(:file_headers))
      next if headers.blank?

      headers.each do |field_key|
        export.export_columns.find_or_create_by!(field_key: field_key.to_s)
      end
    end
  end

  def parse_file_headers(raw)
    return [] if raw.blank?

    parsed = raw.is_a?(Array) ? raw : JSON.parse(raw)
    Array(parsed).map(&:to_s).reject(&:blank?)
  rescue JSON::ParserError
    []
  end
end
