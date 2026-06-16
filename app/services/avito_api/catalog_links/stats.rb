# frozen_string_literal: true

module AvitoApi
  module CatalogLinks
    NOT_FOUND_SAMPLES_LIMIT = 500

    Stats = Struct.new(
      :linked, :existing, :not_found, :skipped, :conflicts, :errors, :not_found_samples,
      keyword_init: true
    ) do
      def self.empty
        new(
          linked: 0, existing: 0, not_found: 0, skipped: 0, conflicts: 0,
          errors: [], not_found_samples: []
        )
      end

      def merge!(other)
        self.linked += other.linked
        self.existing += other.existing
        self.not_found += other.not_found
        self.skipped += other.skipped
        self.conflicts += other.conflicts
        self.errors.concat(Array(other.errors))
        merge_not_found_samples!(other.not_found_samples)
        self
      end

      def to_h
        {
          linked: linked,
          existing: existing,
          not_found: not_found,
          skipped: skipped,
          conflicts: conflicts,
          errors: errors,
          not_found_samples: not_found_samples
        }
      end

      private

      def merge_not_found_samples!(samples)
        Array(samples).each do |sample|
          break if not_found_samples.size >= NOT_FOUND_SAMPLES_LIMIT

          not_found_samples << sample
        end
      end
    end
  end
end
