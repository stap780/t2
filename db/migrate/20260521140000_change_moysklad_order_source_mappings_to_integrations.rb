# frozen_string_literal: true

class ChangeMoyskladOrderSourceMappingsToIntegrations < ActiveRecord::Migration[8.1]
  class Mapping < ApplicationRecord
    self.table_name = "moysklad_order_source_mappings"
  end

  def up
    add_reference :moysklad_order_source_mappings, :avito, foreign_key: true
    add_reference :moysklad_order_source_mappings, :insale, foreign_key: true

    Mapping.reset_column_information
    Mapping.find_each do |mapping|
      base_attrs = mapping.attributes.slice(
        "moysklad_id",
        "ms_attribute_href",
        "ms_attribute_name",
        "ms_custom_entity_href",
        "ms_custom_entity_name",
        "created_at",
        "updated_at"
      )

      case mapping.source_key
      when "avito"
        Avito.find_each do |avito|
          Mapping.create!(base_attrs.merge("avito_id" => avito.id))
        end
      when "insales"
        Insale.find_each do |insale|
          Mapping.create!(base_attrs.merge("insale_id" => insale.id))
        end
      end

      mapping.destroy!
    end

    remove_index :moysklad_order_source_mappings,
                 name: "index_ms_order_source_mappings_on_moysklad_and_source"
    remove_column :moysklad_order_source_mappings, :source_key, :string

    add_index :moysklad_order_source_mappings,
              %i[moysklad_id avito_id],
              unique: true,
              where: "avito_id IS NOT NULL",
              name: "index_ms_order_source_mappings_on_moysklad_and_avito"
    add_index :moysklad_order_source_mappings,
              %i[moysklad_id insale_id],
              unique: true,
              where: "insale_id IS NOT NULL",
              name: "index_ms_order_source_mappings_on_moysklad_and_insale"
  end

  def down
    add_column :moysklad_order_source_mappings, :source_key, :string

    remove_index :moysklad_order_source_mappings,
                 name: "index_ms_order_source_mappings_on_moysklad_and_insale"
    remove_index :moysklad_order_source_mappings,
                 name: "index_ms_order_source_mappings_on_moysklad_and_avito"
    add_index :moysklad_order_source_mappings,
              %i[moysklad_id source_key],
              unique: true,
              name: "index_ms_order_source_mappings_on_moysklad_and_source"

    remove_reference :moysklad_order_source_mappings, :insale, foreign_key: true
    remove_reference :moysklad_order_source_mappings, :avito, foreign_key: true
  end
end
