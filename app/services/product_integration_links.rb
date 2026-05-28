# frozen_string_literal: true

# Ссылки на внешние витрины (МойСклад, InSales, Avito) для строки списка товаров.
# МС/InSales — varbind первого варианта; Avito — varbind на Product (avitoId в value).
# При index с includes(:bindings, variants: :bindings) — без N+1.
#
#   ProductIntegrationLinks.new(product).call
class ProductIntegrationLinks
  Link = Struct.new(:key, :label, :url, :css, keyword_init: true)

  def initialize(product)
    @product = product
  end

  def call
    links = []
    variant = @product.variants.first

    if variant
      barcode = variant.barcode.to_s
      if barcode.present?
        state = scan_variant_bindings(variant)
        links << moysklad_link(barcode) if state[:moysklad]
        links << insale_link(barcode) if state[:insale]
      end
    end

    avito_bindings = scan_product_avito_bindings
    avito_by_id = load_avito_by_id(avito_bindings.keys)
    avito_bindings.sort.each do |bindable_id, avito_item_id|
      links << avito_link(bindable_id, avito_item_id, avito_by_id[bindable_id])
    end

    links
  end

  private

  def scan_variant_bindings(variant)
    moysklad_id = Moysklad.first&.id
    moysklad = false
    insale = false

    variant.bindings.each do |vb|
      case vb.bindable_type
      when "Moysklad"
        moysklad = true if moysklad_id && vb.bindable_id == moysklad_id
      when "Insale"
        insale = true
      end
    end

    { moysklad: moysklad, insale: insale }
  end

  def scan_product_avito_bindings
    @product.bindings.each_with_object({}) do |vb, acc|
      next unless vb.bindable_type == "Avito"
      next if vb.value.blank?

      acc[vb.bindable_id] = vb.value
    end
  end

  def load_avito_by_id(avito_ids)
    return {} if avito_ids.empty?

    Avito.where(id: avito_ids.to_a).index_by(&:id)
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

  def avito_link(bindable_id, avito_item_id, avito = nil)
    Link.new(
      key: "avito-#{bindable_id}",
      label: avito_label(bindable_id, avito),
      url: avito_item_url(avito_item_id),
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

  def avito_item_url(avito_item_id)
    "https://www.avito.ru/#{avito_item_id}"
  end
end
