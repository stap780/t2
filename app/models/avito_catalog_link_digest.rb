# frozen_string_literal: true

class AvitoCatalogLinkDigest < ApplicationRecord
  belongs_to :avito
  belongs_to :user, optional: true

  validates :digest_date, presence: true
  validates :avito_id, uniqueness: { scope: :digest_date }

  def self.accumulate!(avito:, user:, stats:)
    digest = find_or_initialize_by(avito: avito, digest_date: Date.current)
    digest.user_id ||= user&.id
    digest.linked += stats.linked
    digest.existing += stats.existing
    digest.not_found += stats.not_found
    digest.skipped += stats.skipped
    digest.conflicts += stats.conflicts
    digest.errors_list = digest.errors_list + Array(stats.errors)
    digest.not_found_samples = merge_samples(digest.not_found_samples, stats.not_found_samples)
    digest.save!
  end

  def to_stats
    AvitoApi::CatalogLinks::Stats.new(
      linked: linked,
      existing: existing,
      not_found: not_found,
      skipped: skipped,
      conflicts: conflicts,
      errors: errors_list,
      not_found_samples: not_found_samples
    )
  end

  def self.merge_samples(existing, incoming)
    merged = Array(existing).dup
    Array(incoming).each do |sample|
      break if merged.size >= AvitoApi::CatalogLinks::NOT_FOUND_SAMPLES_LIMIT

      merged << sample
    end
    merged
  end
  private_class_method :merge_samples
end
