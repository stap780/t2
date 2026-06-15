# frozen_string_literal: true

module OrdersIntegration
  # Cutover: заказы, созданные в источнике до orders_integration_start_at,
  # не импортируются, если их ещё нет в реестре t2.
  class Cutover
    SKIP_LOG_TAG = "[OrdersIntegration::Cutover]".freeze

    class << self
      def at
        Moysklad.first&.orders_integration_start_at
      end

      def enabled?
        at.present?
      end

      def skip?(known_in_app:, source_created_at:)
        return false unless enabled?
        return false if known_in_app

        parsed = parse_time(source_created_at)
        return false if parsed.nil?

        parsed < at
      end

      def avito_date_from_param
        return nil unless enabled?

        at.to_i
      end

      def parse_time(value)
        return value if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
        return nil if value.blank?

        Time.zone.parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def parse_moysklad_time(value)
        return nil if value.blank?

        ActiveSupport::TimeZone["Europe/Moscow"].parse(value.to_s)
      rescue ArgumentError, TypeError
        nil
      end

      def log_skip(source:, identifier:)
        Rails.logger.info(
          "#{SKIP_LOG_TAG} skipped source=#{source} id=#{identifier} " \
          "cutover=#{at&.iso8601}"
        )
      end
    end
  end
end
