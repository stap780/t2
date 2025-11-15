module Bindable
  extend ActiveSupport::Concern

  included do
    has_many :bindings, class_name: 'Varbind', as: :record, dependent: :destroy
  end

  def show_path
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self))
  end

  def bindings_path
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self) + [:varbinds])
  end

  def binding_new_path
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self) + [:varbind], action: :new)
  end

  def binding_edit_path(binding)
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self) + [binding], action: :edit)
  end

  def binding_path(binding)
    Rails.application.routes.url_helpers.polymorphic_path(polymorphic_stack(self) + [binding])
  end

  def broadcast_target_for_bindings
    raise NotImplementedError, "#{self.class} must implement #broadcast_target_for_bindings"
  end

  def broadcast_target_id_for_bindings
    raise NotImplementedError, "#{self.class} must implement #broadcast_target_id_for_bindings"
  end

  def broadcast_locals_for_binding(binding)
    raise NotImplementedError, "#{self.class} must implement #broadcast_locals_for_binding"
  end

  private

  # Build the polymorphic stack like [parent, self]
  # В t2 нет accounts/users в маршрутах, поэтому просто [parent, self]
  def polymorphic_stack(record)
    stack = []
    parent = parent_resource_for_bindings(record)
    stack << parent if parent
    stack << record
    stack
  end

  def parent_resource_for_bindings(record)
    # Для Variant не используем parent (product), используем только сам variant
    nil
  end
end

