# frozen_string_literal: true

require "test_helper"

module AvitoApi
  module Autoload
    class SyncCatalogTest < ActiveSupport::TestCase
      setup do
        @avito = Avito.create!(
          title: "Test Avito",
          api_id: "client-id-#{SecureRandom.hex(4)}",
          api_secret: "secret-#{SecureRandom.hex(4)}"
        )
        @product = Product.create!(title: "Товар")
        @product.variants.create!(quantity: 1, price: 100)
      end

      test "links products from autoload report items" do
        product_id = @product.id.to_s
        fake_client = Class.new do
          define_method(:initialize) { |pid| @pid = pid }
          define_method(:get) do |path, params: {}|
            case path
            when "/autoload/v2/reports"
              { "reports" => [{ "id" => 1, "finished_at" => "2026-01-01", "status" => "success" }] }
            when "/autoload/v2/reports/1/items"
              {
                "items" => [{ "ad_id" => @pid, "avito_id" => 7_890_403_963 }],
                "meta" => { "pages" => 1, "page" => 0 }
              }
            end
          end
        end

        sync = SyncCatalog.new(avito: @avito)
        sync.instance_variable_set(:@client, fake_client.new(product_id))

        AvitoApi::Auth.stub(:access_token, "token") do
          stats = sync.call
          assert_equal 1, stats.linked
        end

        assert Varbind.exists?(record: @product, bindable: @avito, value: "7890403963")
      end
    end
  end
end
