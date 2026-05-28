# frozen_string_literal: true

module MoyskladApi
  class ReferenceData
    def self.organizations(moysklad)
      list_entities(moysklad, "organization")
    end

    def self.stores(moysklad)
      list_entities(moysklad, "store")
    end

    def self.customerorder_metadata(moysklad)
      Client.get_json(moysklad, "#{Api::API_BASE}/entity/customerorder/metadata")
    end

    def self.customerorder_states(moysklad)
      states_from_metadata(customerorder_metadata(moysklad))
    rescue StandardError => e
      Rails.logger.warn "[MoyskladApi::ReferenceData] customerorder_states: #{e.message}"
      []
    end

    def self.customerorder_attributes(moysklad)
      list_attribute_metadata(moysklad, "customerorder")
    rescue StandardError => e
      Rails.logger.warn "[MoyskladApi::ReferenceData] customerorder_attributes: #{e.message}"
      []
    end

    def self.states_from_metadata(meta)
      normalize_collection(meta["states"]).filter_map do |state|
        next unless state.is_a?(Hash)

        {
          href: state.dig("meta", "href"),
          name: state["name"],
          id: state["id"]
        }
      end
    end

    def self.list_attribute_metadata(moysklad, entity_type)
      data = Client.get_json(
        moysklad,
        "#{Api::API_BASE}/entity/#{entity_type}/metadata/attributes"
      )
      (data["rows"] || []).filter_map do |row|
        next unless row.is_a?(Hash)

        {
          href: row.dig("meta", "href"),
          name: row["name"],
          type: row["type"],
          required: row["required"] == true,
          custom_entity_meta_href: row.dig("customEntityMeta", "href")
        }
      end
    end

    def self.custom_entity_values(moysklad, custom_entity_meta_href)
      catalog_id = custom_entity_meta_href.to_s.split("/").last
      data = Client.get_json(moysklad, "#{Api::API_BASE}/entity/customentity/#{catalog_id}")
      (data["rows"] || []).filter_map do |row|
        next unless row.is_a?(Hash)

        { href: row.dig("meta", "href"), name: row["name"] }
      end
    rescue StandardError => e
      Rails.logger.warn "[MoyskladApi::ReferenceData] custom_entity_values: #{e.message}"
      []
    end

    def self.list_entities(moysklad, entity_type)
      data = Client.get_json(moysklad, "#{Api::API_BASE}/entity/#{entity_type}?limit=100")
      (data["rows"] || []).map do |row|
        { href: row.dig("meta", "href"), name: row["name"], id: row["id"] }
      end
    rescue StandardError => e
      Rails.logger.warn "[MoyskladApi::ReferenceData] #{entity_type}: #{e.message}"
      []
    end

    def self.normalize_collection(value)
      case value
      when Array then value
      when Hash then value.values
      else []
      end
    end

    private_class_method :normalize_collection
  end
end
