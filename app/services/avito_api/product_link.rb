# frozen_string_literal: true

module AvitoApi
  # Связь Product ↔ Avito по avitoId (Varbind на Product).
  class ProductLink
    Result = Struct.new(:status, :product, :error, keyword_init: true)

    def self.resolve_variant(avito:, line:)
      new(avito:).resolve_variant(line)
    end

    def self.link!(avito:, product:, avito_id:)
      new(avito:).link!(product, avito_id)
    end

    def initialize(avito:)
      @avito = avito
    end

    def resolve_variant(line)
      avito_id = extract_avito_id(line)
      real_id = extract_real_id(line)

      if avito_id.present?
        product = product_by_avito_id(avito_id)
        if product.nil? && real_id.present?
          product = ProductRealId.find_product(real_id)
          link!(product, avito_id) if product
        end
        return variant_for(product) if product
      end

      legacy_variant(real_id) if real_id.present?
    end

    def link!(product, avito_id)
      avito_id = avito_id.to_s.strip
      return Result.new(status: :invalid, error: "blank_avito_id") if avito_id.blank?
      return Result.new(status: :invalid, error: "blank_product") if product.blank?

      existing = Varbind.find_by(bindable: @avito, value: avito_id)
      if existing
        if existing.record_type == "Product" && existing.record_id == product.id
          return Result.new(status: :existing, product: product)
        end

        return Result.new(
          status: :conflict,
          product: product,
          error: "avito_id #{avito_id} already linked to #{existing.record_type}##{existing.record_id}"
        )
      end

      product.bindings.create!(bindable: @avito, value: avito_id)
      Result.new(status: :linked, product: product)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(status: :error, product: product, error: e.record.errors.full_messages.join(", "))
    end

    private

    def extract_avito_id(line)
      line["avitoId"].presence || line["avito_id"].presence
    end

    def extract_real_id(line)
      line["id"].presence || line["itemId"].presence || line["listingId"].presence || line["ad_id"].presence
    end

    def product_by_avito_id(avito_id)
      Varbind.find_by(bindable: @avito, value: avito_id.to_s, record_type: "Product")&.record
    end

    def variant_for(product)
      product.variants.order(:id).first
    end

    def legacy_variant(real_id)
      varbind = Varbind.find_by(bindable: @avito, value: real_id.to_s)
      record = varbind&.record
      return record if record.is_a?(Variant)
      return variant_for(record) if record.is_a?(Product)

      nil
    end
  end
end
