# frozen_string_literal: true

# Ссылки на внешние витрины (МойСклад, InSales, Avito) для строки списка товаров.
# Только привязки первого варианта. При index с includes(variants: :bindings) — без N+1 по varbinds.
#
#   ProductIntegrationLinks.new(product).call
class ProductIntegrationLinks
  Link = Struct.new(:key, :label, :url, :css, keyword_init: true)

  def initialize(product)
    @product = product
  end

  def call
    v = @product.variants.first
    return [] unless v

    barcode = v.barcode.to_s
    return [] if barcode.blank?

    state = scan_variant_bindings(v)
    avito_by_id = load_avito_by_id(state[:avito_ids])

    [].tap do |links|
      links << moysklad_link(barcode) if state[:moysklad]
      links << insale_link(barcode) if state[:insale]
      state[:avito_ids].sort.each { |id| links << avito_link(id, barcode, avito_by_id[id]) }
    end
  end

  private

  def scan_variant_bindings(variant)
    moysklad_id = Moysklad.first&.id
    avito_ids = Set.new
    moysklad = false
    insale = false

    variant.bindings.each do |vb|
      case vb.bindable_type
      when "Moysklad"
        moysklad = true if moysklad_id && vb.bindable_id == moysklad_id
      when "Insale"
        insale = true
      when "Avito"
        avito_ids << vb.bindable_id
      end
    end

    { moysklad: moysklad, insale: insale, avito_ids: avito_ids }
  end

  def load_avito_by_id(avito_ids)
    return {} if avito_ids.empty? || !avito_model_configured?

    Avito.where(id: avito_ids.to_a).index_by(&:id)
  end

  def avito_model_configured?
    defined?(::Avito) && Avito < ApplicationRecord
  end

  def moysklad_link(barcode)
    Link.new(
      key: "moysklad", label: "МС",
      url: moysklad_url(barcode),
      css: "bg-blue-100 text-blue-800"
    )
  end

  def insale_link(barcode)
    Link.new(
      key: "insale", label: "InS",
      url: insale_url(barcode),
      css: "bg-green-100 text-green-800"
    )
  end

  def avito_link(bindable_id, barcode, avito = nil)
    Link.new(
      key: "avito-#{bindable_id}",
      label: avito_label(bindable_id, avito),
      url: avito_url(bindable_id, barcode, avito),
      css: "bg-amber-100 text-amber-900"
    )
  end

  def moysklad_url(barcode)
    "https://online.moysklad.ru/app/#good?global_codeFilter=#{barcode},equals"
  end

  def insale_url(barcode)
    "https://dizauto.ru/admin2/collections/-1?q=#{barcode}"
  end

  def avito_label(bindable_id, avito = nil)
    t = avito.try(:title)
    t.presence || "Av.#{bindable_id}"
  end

  def avito_url(_bindable_id, barcode, avito = nil)
    q = URI.encode_www_form_component(barcode)
    if avito&.respond_to?(:product_list_url)
      return avito.product_list_url(q)
    end
    "https://www.avito.ru/profile/pro/items?searchText=#{q}"
  end
end
