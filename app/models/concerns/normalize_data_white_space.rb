module NormalizeDataWhiteSpace
  extend ActiveSupport::Concern

  included do
    before_validation :normalize_whitespace
  end

  private

  def normalize_whitespace
    self.class.columns.each do |column|
      if column.type == :string && self[column.name].present?
        self[column.name] = self[column.name].strip.squeeze(' ')
      end
    end
  end
end

