# frozen_string_literal: true

require "test_helper"

module Api
  class AvitoCatalogLinksControllerTest < ActionDispatch::IntegrationTest
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

    test "returns unauthorized without bearer token" do
      post api_avito_catalog_links_url,
           params: { items: [] },
           as: :json

      assert_response :unauthorized
    end

    test "returns unprocessable entity when items missing" do
      post api_avito_catalog_links_url,
           params: { items: [] },
           headers: auth_headers,
           as: :json

      assert_response :unprocessable_entity
      assert_equal "items_required", response.parsed_body["error"]
    end

    test "links products from items batch" do
      post api_avito_catalog_links_url,
           params: {
             items: [
               {
                 avito_profile_id: @avito.profileid,
                 real_id: @product.id.to_s,
                 avito_id: "7890403963"
               }
             ]
           },
           headers: auth_headers,
           as: :json

      assert_response :success
      body = response.parsed_body
      assert_equal 1, body["linked"]
      assert Varbind.exists?(record: @product, bindable: @avito, value: "7890403963")
      assert_equal 1, AvitoCatalogLinkDigest.count
    end

    test "skips unknown avito profile id" do
      post api_avito_catalog_links_url,
           params: {
             items: [
               {
                 avito_profile_id: 99_999_999,
                 real_id: @product.id.to_s,
                 avito_id: "7890403963"
               }
             ]
           },
           headers: auth_headers,
           as: :json

      assert_response :success
      body = response.parsed_body
      assert_equal 1, body["skipped"]
      assert_includes body["errors"].first, "unknown avito_profile_id"
    end

    private

    def auth_headers
      { "Authorization" => "Bearer #{@user.api_token}" }
    end
  end
end
