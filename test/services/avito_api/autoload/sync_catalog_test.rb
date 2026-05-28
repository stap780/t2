# frozen_string_literal: true

require "test_helper"

module AvitoApi
  module Autoload
    class SyncCatalogTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      setup do
        BarcodeCounter.find_or_create_by!(id: 1) { |c| c.last_value = 900_000 }
        @avito = Avito.create!(
          title: "Test Avito",
          api_id: "client-id-#{SecureRandom.hex(4)}",
          api_secret: "secret-#{SecureRandom.hex(4)}"
        )
        @product = Product.create!(title: "Товар", status: "active")
        @product.variants.create!(quantity: 1, price: 100)
      end

      test "links products from autoload report items with per_page 200" do
        product_id = @product.id.to_s
        items_requests = []
        fake_client = build_fake_client(product_id, items_requests: items_requests)

        sync = SyncCatalog.new(avito: @avito)
        sync.instance_variable_set(:@client, fake_client)

        with_singleton_stub(AvitoApi::Auth, :access_token, "token") do
          stats = sync.call
          assert_equal 1, stats.linked
        end

        assert_equal 1, items_requests.size
        assert_equal({ page: 0, per_page: SyncCatalog::PER_PAGE }, items_requests.first)
        assert Varbind.exists?(record: @product, bindable: @avito, value: "7890403963")
      end

      test "sleeps between paginated report item requests" do
        product_id = @product.id.to_s
        items_requests = []
        fake_client = build_fake_client(
          product_id,
          items_requests: items_requests,
          pages: 2,
          second_page_items: []
        )
        sync = SyncCatalog.new(avito: @avito)
        sync.instance_variable_set(:@client, fake_client)
        sleeps = []
        sync.define_singleton_method(:sleep) { |seconds| sleeps << seconds }

        with_singleton_stub(AvitoApi::Auth, :access_token, "token") do
          stats = sync.call
          assert_equal 1, stats.linked
        end

        assert_equal 2, items_requests.size
        assert_equal [1], sleeps
      end

      test "skips non-active products" do
        @product.update!(status: "pending")
        product_id = @product.id.to_s
        fake_client = build_fake_client(product_id)
        sync = SyncCatalog.new(avito: @avito)
        sync.instance_variable_set(:@client, fake_client)

        with_singleton_stub(AvitoApi::Auth, :access_token, "token") do
          stats = sync.call
          assert_equal 0, stats.linked
          assert_equal 1, stats.skipped
        end

        refute Varbind.exists?(record: @product, bindable: @avito)
      end

      test "skips items without avito_id" do
        product_id = @product.id.to_s
        fake_client = build_fake_client(
          product_id,
          extra_items: [{ "ad_id" => product_id }]
        )
        sync = SyncCatalog.new(avito: @avito)
        sync.instance_variable_set(:@client, fake_client)

        with_singleton_stub(AvitoApi::Auth, :access_token, "token") do
          stats = sync.call
          assert_equal 1, stats.linked
          assert_equal 1, stats.skipped
        end
      end

      test "returns no_avito_token when token is blank" do
        sync = SyncCatalog.new(avito: @avito)

        with_singleton_stub(AvitoApi::Auth, :access_token, nil) do
          stats = sync.call
          assert_includes stats.errors, "no_avito_token"
        end
      end

      test "returns no_autoload_report when no successful report" do
        fake_client = Class.new do
          define_method(:get) { |_path, params: {}| { "reports" => [] } }
        end.new
        sync = SyncCatalog.new(avito: @avito)
        sync.instance_variable_set(:@client, fake_client)

        with_singleton_stub(AvitoApi::Auth, :access_token, "token") do
          stats = sync.call
          assert_includes stats.errors, "no_autoload_report"
        end
      end

      private

      def build_fake_client(product_id, items_requests: nil, pages: 1, second_page_items: [], extra_items: [])
        Class.new do
          define_method(:initialize) do |pid, opts|
            @pid = pid
            @items_requests = opts[:items_requests]
            @pages = opts[:pages]
            @second_page_items = opts[:second_page_items]
            @extra_items = opts[:extra_items]
          end

          define_method(:get) do |path, params: {}|
            case path
            when "/autoload/v2/reports"
              { "reports" => [{ "id" => 1, "finished_at" => "2026-01-01", "status" => "success" }] }
            when "/autoload/v2/reports/1/items"
              @items_requests&.<<(params.dup)
              page = params[:page].to_i
              items =
                if page.zero?
                  [{ "ad_id" => @pid, "avito_id" => 7_890_403_963 }, *@extra_items]
                else
                  @second_page_items
                end
              {
                "items" => items,
                "meta" => { "pages" => @pages, "page" => page, "per_page" => SyncCatalog::PER_PAGE }
              }
            end
          end
        end.new(
          product_id,
          items_requests: items_requests,
          pages: pages,
          second_page_items: second_page_items,
          extra_items: extra_items
        )
      end
    end
  end
end
