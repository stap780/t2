class CreateClients < ActiveRecord::Migration[8.0]
  def change
    create_table :clients do |t|
      t.string :surname
      t.string :name
      t.string :middlename
      t.string :phone
      t.string :email

      t.timestamps
    end
  end
end
