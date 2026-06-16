# frozen_string_literal: true

class AddApiTokenToUsers < ActiveRecord::Migration[8.1]
  def up
    add_column :users, :api_token, :string
    add_index :users, :api_token, unique: true

    User.reset_column_information
    User.where(api_token: nil).find_each do |user|
      user.update_column(:api_token, generate_api_token)
    end

    change_column_null :users, :api_token, false
  end

  def down
    remove_index :users, :api_token
    remove_column :users, :api_token
  end

  private

  def generate_api_token
    loop do
      token = SecureRandom.urlsafe_base64(32)
      break token unless User.exists?(api_token: token)
    end
  end
end
