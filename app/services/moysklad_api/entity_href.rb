# frozen_string_literal: true

module MoyskladApi
  module EntityHref
    module_function

    def for_entity(entity, id)
      "#{Api::API_BASE}/entity/#{entity}/#{id}"
    end

    def counterparty(id)
      for_entity("counterparty", id)
    end

    def extract_id(href, entity:)
      value = href.to_s.strip
      return value if value.present? && !value.include?("/")

      match = value.match(%r{/entity/#{Regexp.escape(entity)}/([^/?]+)})
      match&.[](1)
    end
  end
end
