# frozen_string_literal: true

require "test_helper"

module AvitoApi
  module Orders
    class DownloadLabelTest < ActiveSupport::TestCase
      setup do
        @avito = Avito.create!(
          title: "Test Avito",
          api_id: "client-id-#{SecureRandom.hex(4)}",
          api_secret: "secret-#{SecureRandom.hex(4)}"
        )
        @order = Order.create!(
          source: "avito",
          avito: @avito,
          avito_order_id: "50000000051131229",
          avito_marketplace_id: "70000000429007323"
        )
        @pvz_payload = { "delivery" => { "serviceType" => "pvz" } }
      end

      test "skips when delivery is not pvz" do
        result = DownloadLabel.call(
          order: @order,
          payload: { "delivery" => { "serviceType" => "dbs" } }
        )

        assert result.skipped
        assert_equal "not_pvz", result.error
      end

      test "skips when label already attached" do
        @order.avito_label.attach(
          io: StringIO.new("%PDF-1.4"),
          filename: "existing.pdf",
          content_type: "application/pdf"
        )

        result = DownloadLabel.call(order: @order, payload: @pvz_payload)

        assert result.skipped
        assert_equal "already_attached", result.error
      end

      test "downloads and attaches label for pvz order" do
        pdf_bytes = "%PDF-1.4 test label"
        task_id = "task-123"

        AvitoApi::Auth.stub(:access_token, "token") do
          RestClient.stub(:post, label_task_response(task_id)) do
            RestClient.stub(:get, label_pdf_response(pdf_bytes)) do
              result = DownloadLabel.call(order: @order, payload: @pvz_payload)

              assert result.success
              assert @order.avito_label.attached?
              assert_equal "avito_70000000429007323.pdf", @order.avito_label.filename.to_s
            end
          end
        end
      end

      private

      def label_task_response(task_id)
        lambda do |_url, _body, _headers|
          Struct.new(:body).new({ taskID: task_id }.to_json)
        end
      end

      def label_pdf_response(pdf_bytes)
        lambda do |_url, _headers|
          Struct.new(:body, :headers).new(pdf_bytes, { content_type: "application/pdf" })
        end
      end
    end
  end
end
