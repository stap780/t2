class CreateBarcodeCounters < ActiveRecord::Migration[8.0]
  def change
    create_table :barcode_counters do |t|
      t.integer :last_value, default: 900000, null: false
    end
    # Одна строка-счётчик
    execute "INSERT INTO barcode_counters (id, last_value) VALUES (1, 900000)"
  end
end
