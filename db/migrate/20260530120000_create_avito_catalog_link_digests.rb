# frozen_string_literal: true

class CreateAvitoCatalogLinkDigests < ActiveRecord::Migration[8.1]
  def change
    create_table :avito_catalog_link_digests do |t|
      t.references :avito, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.date :digest_date, null: false
      t.integer :linked, null: false, default: 0
      t.integer :existing, null: false, default: 0
      t.integer :not_found, null: false, default: 0
      t.integer :skipped, null: false, default: 0
      t.integer :conflicts, null: false, default: 0
      t.jsonb :errors_list, null: false, default: []
      t.jsonb :not_found_samples, null: false, default: []

      t.timestamps
    end

    add_index :avito_catalog_link_digests,
              %i[avito_id digest_date],
              unique: true,
              name: "index_avito_catalog_link_digests_on_avito_and_date"
  end
end
