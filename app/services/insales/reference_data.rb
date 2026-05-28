# frozen_string_literal: true

module Insales
  class ReferenceData
    ORDER_FIELD_DESTINY = 3

    def self.order_fields(insale)
      new(insale).order_fields
    end

    def initialize(insale)
      @insale = insale
    end

    def order_fields
      @insale.api_init
      Array(InsalesApi::Field.all).filter_map do |field|
        attrs = field.respond_to?(:attributes) ? field.attributes.stringify_keys : field.stringify_keys
        next unless attrs["destiny"].to_i == ORDER_FIELD_DESTINY

        {
          id: attrs["id"],
          handle: attrs["handle"].presence,
          title: attrs["office_title"].presence || attrs["title"].presence || attrs["handle"].presence || attrs["id"].to_s
        }
      end
    rescue StandardError => e
      Rails.logger.warn "[Insales::ReferenceData] order_fields: #{e.message}"
      []
    end
  end
end
