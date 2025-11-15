class Variant < ApplicationRecord
  include ActionView::RecordIdentifier
  include Bindable

  belongs_to :product
  has_many :list_items, as: :item
  before_destroy :prevent_destroy_if_last

  def broadcast_target_for_bindings
    [product, [self, :bindings]]
  end

  def broadcast_target_id_for_bindings
    dom_id(product, dom_id(self, :bindings))
  end

  def broadcast_locals_for_binding(binding)
    { record: self, varbind: binding }
  end

  def self.ransackable_attributes(auth_object = nil)
    Variant.attribute_names
  end

  private

  def prevent_destroy_if_last
    if product.variants.count <= 1
      errors.add(:base, 'Cannot delete the last variant')
      throw(:abort)
    end
  end

end
