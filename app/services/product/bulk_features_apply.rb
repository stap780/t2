# Массовое применение пар (property_id, characteristic_id) к списку товаров
# из bulk-формы (те же поля, что nested features_attributes у карточки товара).
class Product::BulkFeaturesApply
  Result = Struct.new(:ok, :updated_count, :failure, :error_message, keyword_init: true)

  def initialize(product_ids:, features_attributes:)
    @product_ids = normalize_product_ids(product_ids)
    @features_attributes = features_attributes
  end

  def call
    return failure(:missing_products) if @product_ids.empty?

    pairs = extract_pairs
    return failure(:no_changes) if pairs.empty?
    return failure(:invalid_pair) unless pairs_valid?(pairs)

    persist_pairs(pairs)
  end

  private

  def normalize_product_ids(raw)
    Array(raw).compact_blank.map(&:to_i).uniq
  end

  def extract_pairs
    return [] if @features_attributes.blank?

    pairs_by_property = {}
    @features_attributes.each do |_key, row|
      next if row.blank?

      h = row_to_hash(row)
      next if ActiveModel::Type::Boolean.new.cast(h["_destroy"])

      property_id = h["property_id"].presence&.to_i
      characteristic_id = h["characteristic_id"].presence&.to_i
      next if property_id.blank? || characteristic_id.blank?

      pairs_by_property[property_id] = characteristic_id
    end
    pairs_by_property.to_a
  end

  def row_to_hash(row)
    case row
    when Hash
      row.stringify_keys
    when ActionController::Parameters
      row.to_h.stringify_keys
    else
      {}
    end
  end

  def pairs_valid?(pairs)
    pairs.all? do |property_id, characteristic_id|
      Characteristic.exists?(id: characteristic_id, property_id: property_id)
    end
  end

  def persist_pairs(pairs)
    updated = 0
    error_message = nil

    Product.transaction do
      Product.where(id: @product_ids).find_each do |product|
        changed = false

        pairs.each do |property_id, characteristic_id|
          feature = product.features.find_by(property_id: property_id)
          next if feature&.characteristic_id == characteristic_id

          failed_record = nil
          ok =
            if feature
              failed_record = feature
              feature.update(characteristic_id: characteristic_id)
            else
              nf = product.features.build(property_id: property_id, characteristic_id: characteristic_id)
              failed_record = nf
              nf.save
            end

          unless ok
            error_message = failed_record.errors.full_messages.join(", ").presence
            updated = 0
            raise ActiveRecord::Rollback
          end

          changed = true
        end

        product.touch if changed
        updated += 1
      end
    end

    if error_message.present?
      Result.new(ok: false, updated_count: 0, failure: :save_error, error_message: error_message)
    else
      Result.new(ok: true, updated_count: updated, failure: nil, error_message: nil)
    end
  end

  def failure(failure_key, error_message = nil)
    Result.new(ok: false, updated_count: 0, failure: failure_key, error_message: error_message)
  end
end