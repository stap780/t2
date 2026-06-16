# frozen_string_literal: true

require "test_helper"

module AvitoApi
  module CatalogLinks
    class ImportTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      setup do
        BarcodeCounter.find_or_create_by!(id: 1) { |c| c.last_value = 900_000 }
        @user = User.create!(
          name: "Integration",
          email_address: "integration-#{SecureRandom.hex(4)}@example.com",
          password: "password123",
          password_confirmation: "password123"
        )
        @avito = Avito.create!(
          title: "Test Avito",
          api_id: "client-id-#{SecureRandom.hex(4)}",
          api_secret: "secret-#{SecureRandom.hex(4)}",
          profileid: 71_941_621
        )
        @product = Product.create!(title: "Товар", status: "active")
        @product.variants.create!(quantity: 1, price: 100)
      end

      test "imports batch and accumulates digest" do
        stats = Import.call(
          user: @user,
          items: [
            {
              avito_profile_id: @avito.profileid,
              real_id: @product.id.to_s,
              avito_id: "7890403963"
            },
            {
              avito_profile_id: @avito.profileid,
              real_id: @product.id.to_s,
              avito_id: "7890403963"
            }
          ]
        )

        assert_equal 1, stats.linked
        assert_equal 1, stats.existing
        digest = AvitoCatalogLinkDigest.find_by!(avito: @avito, digest_date: Date.current)
        assert_equal 1, digest.linked
        assert_equal 1, digest.existing
        assert_equal @user.id, digest.user_id
      end
    end
  end
end
