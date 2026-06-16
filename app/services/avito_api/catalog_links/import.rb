# frozen_string_literal: true

module AvitoApi
  module CatalogLinks
    class Import
      def self.call(user:, items:)
        new(user:, items:).call
      end

      def initialize(user:, items:)
        @user = user
        @items = Array(items)
        @stats = Stats.empty
        @avito_cache = {}
        @avito_stats = {}
        @avito_by_id = {}
      end

      def call
        @items.each { |row| process_row(row) }
        accumulate_digests!
        @stats
      end

      private

      def process_row(row)
        row = row.stringify_keys
        profile_id = row["avito_profile_id"].presence
        if profile_id.blank?
          @stats.skipped += 1
          @stats.errors << "missing avito_profile_id"
          return
        end

        avito = resolve_avito(profile_id)
        unless avito
          @stats.skipped += 1
          @stats.errors << "unknown avito_profile_id #{profile_id}"
          return
        end

        @avito_by_id[avito.id] = avito
        item_stats = Stats.empty
        ProcessItem.call(avito: avito, row: row, stats: item_stats)
        @stats.merge!(item_stats)
        @avito_stats[avito.id] ||= Stats.empty
        @avito_stats[avito.id].merge!(item_stats)
      end

      def resolve_avito(profile_id)
        key = profile_id.to_s
        @avito_cache[key] ||= Avito.find_by(profileid: key) || Avito.find_by(profileid: profile_id.to_i)
      end

      def accumulate_digests!
        @avito_stats.each do |avito_id, stats|
          avito = @avito_by_id[avito_id]
          next unless avito

          AvitoCatalogLinkDigest.accumulate!(avito: avito, user: @user, stats: stats)
        end
      end
    end
  end
end
