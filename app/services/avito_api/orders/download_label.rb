# frozen_string_literal: true

require "rest-client"
require "stringio"

module AvitoApi
  module Orders
    # Скачивание PDF-этикетки Avito (только ПВЗ) и attach в order.avito_label.
    class DownloadLabel
      LABELS_PATH = "/order-management/1/orders/labels".freeze
      POLL_INTERVAL = 1
      POLL_TIMEOUT = 30

      Result = Struct.new(:success, :skipped, :error, keyword_init: true)

      def self.call(order:, payload: nil, force: false)
        new(order:, payload:, force:).call
      end

      def initialize(order:, payload: nil, force: false)
        @order = order
        @payload = payload
        @force = force
      end

      def call
        payload = resolve_payload
        return Result.new(skipped: true, error: "order_not_found") if payload.blank?
        return Result.new(skipped: true, error: "not_pvz") unless pvz?(payload)
        return Result.new(skipped: true, error: "already_attached") if @order.avito_label.attached? && !@force

        token = AvitoApi::Auth.access_token(@order.avito)
        return Result.new(error: "no_token") if token.blank?

        task_id = create_label_task(token)
        return Result.new(error: "task_create_failed") if task_id.blank?

        pdf_body = poll_label_pdf(token, task_id)
        return Result.new(error: "label_not_ready") if pdf_body.blank?

        attach_pdf(pdf_body)
        Result.new(success: true)
      rescue StandardError => e
        Rails.logger.error "[AvitoApi::Orders::DownloadLabel] #{e.class}: #{e.message}"
        Result.new(error: e.message)
      end

      private

      def marketplace_id
        @order.avito_marketplace_id
      end

      def pvz?(payload)
        payload.dig("delivery", "serviceType") == "pvz"
      end

      def resolve_payload
        return @payload if @payload.present?
        return nil if @order.avito_order_id.blank?

        List.call(
          avito: @order.avito,
          params: { ids: [@order.avito_order_id], page: 1 }
        ).first
      end

      def create_label_task(token)
        response = RestClient.post(
          "#{AvitoApi::Auth::API_BASE}#{LABELS_PATH}",
          { orderIds: [marketplace_id] }.to_json,
          authorization_headers(token)
        )
        body = JSON.parse(response.body)
        body["taskID"] || body["taskId"]
      rescue RestClient::ExceptionWithResponse => e
        Rails.logger.error "[AvitoApi::Orders::DownloadLabel] create #{e.http_code}: #{e.http_body}"
        nil
      end

      def poll_label_pdf(token, task_id)
        deadline = Time.current + POLL_TIMEOUT
        loop do
          pdf = fetch_label_pdf(token, task_id)
          return pdf if pdf.present?
          break if Time.current >= deadline

          sleep POLL_INTERVAL
        end
        nil
      end

      def fetch_label_pdf(token, task_id)
        response = RestClient.get(
          "#{AvitoApi::Auth::API_BASE}#{LABELS_PATH}/#{task_id}/download",
          authorization_headers(token)
        )
        response.body if pdf_response?(response)
      rescue RestClient::ExceptionWithResponse => e
        return nil if e.http_code == 404

        Rails.logger.error "[AvitoApi::Orders::DownloadLabel] download #{e.http_code}: #{e.http_body}"
        raise
      end

      def pdf_response?(response)
        content_type = response.headers[:content_type].to_s
        content_type.include?("pdf") || response.body.bytesize.positive?
      end

      def attach_pdf(pdf_body)
        @order.avito_label.purge if @order.avito_label.attached?
        @order.avito_label.attach(
          io: StringIO.new(pdf_body),
          filename: "avito_#{marketplace_id}.pdf",
          content_type: "application/pdf"
        )
      end

      def authorization_headers(token)
        {
          Authorization: "Bearer #{token}",
          "Content-Type" => "application/json"
        }
      end
    end
  end
end
