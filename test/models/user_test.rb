# frozen_string_literal: true

require "test_helper"

class UserTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  test "assigns api_token on create" do
    user = User.create!(
      email_address: "token-#{SecureRandom.hex(4)}@example.com",
      password: "password123",
      password_confirmation: "password123"
    )

    assert user.api_token.present?
    assert_equal 1, User.where(api_token: user.api_token).count
  end
end
