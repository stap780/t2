# frozen_string_literal: true

module AvitoApi
  # Id объявления в XML автозагрузки: product.id или feature «Старый ID».
  class ProductRealId
    OLD_ID_PROPERTY = "Старый ID"

    def self.export_real_id(product)
      val = product.features_to_h[OLD_ID_PROPERTY]
      val.present? ? val.to_s : product.id.to_s
    end

    def self.find_product(real_id)
      real_id = real_id.to_s.strip
      return nil if real_id.blank?

      product = Product.find_by(id: real_id)
      return product if product

      Product.joins(features: %i[property characteristic])
        .where(properties: { title: OLD_ID_PROPERTY })
        .where(characteristics: { title: real_id })
        .first
    end
  end
end
