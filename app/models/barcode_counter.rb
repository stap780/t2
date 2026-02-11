class BarcodeCounter < ApplicationRecord
  def self.next_value!
    transaction do
      row = lock.first
      next_val = row.last_value + 1
      row.update!(last_value: next_val)
      next_val
    end
  end
end