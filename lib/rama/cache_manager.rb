# frozen_string_literal: true

class Rama::CacheManager
  class << self
    # Page-level caching for admin operations
    def cache_page(key, expires_in: 5.minutes, &block)
      full_key = "flex_admin:page:#{key}"
      Rails.cache.fetch(full_key, expires_in: expires_in, &block)
    end

    # Fragment caching for expensive operations
    def cache_fragment(record, fragment_name, expires_in: 1.hour, &block)
      cache_key = fragment_cache_key(record, fragment_name)
      Rails.cache.fetch(cache_key, expires_in: expires_in, &block)
    end

    # Association count caching with bulk warming
    def cache_association_count(record, association_name, expires_in: 30.minutes)
      cache_key = association_count_cache_key(record, association_name)

      Rails.cache.fetch(cache_key, expires_in: expires_in) do
        record.public_send(association_name).count
      end
    end

    # Bulk cache warming for association counts
    def warm_association_counts(records, association_name, expires_in: 30.minutes)
      return if records.empty?

      # Find records that don't have cached counts
      uncached_records = records.reject { |record|
        cache_key = association_count_cache_key(record, association_name)
        Rails.cache.exist?(cache_key)
      }

      return if uncached_records.empty?

      # Bulk load counts using a single query
      counts = bulk_association_counts(uncached_records, association_name)

      # Cache individual counts
      counts.each do |record_id, count|
        record = uncached_records.find { |r| r.id == record_id }
        next unless record

        cache_key = association_count_cache_key(record, association_name)
        Rails.cache.write(cache_key, count, expires_in: expires_in)
      end
    end

    # Search result caching
    def cache_search_results(search_key, expires_in: 10.minutes, &block)
      cache_key = "flex_admin:search:#{Digest::MD5.hexdigest(search_key)}"
      Rails.cache.fetch(cache_key, expires_in: expires_in, &block)
    end

    # Dashboard metrics caching
    def cache_dashboard_metrics(expires_in: 5.minutes, &block)
      Rails.cache.fetch('flex_admin:dashboard:metrics', expires_in: expires_in, &block)
    end

    # Resource statistics caching
    def cache_resource_stats(resource_class, expires_in: 15.minutes, &block)
      cache_key = "flex_admin:stats:#{resource_class.name.underscore}"
      Rails.cache.fetch(cache_key, expires_in: expires_in, &block)
    end

    # Cache invalidation
    def invalidate_resource_cache(resource_class)
      pattern = "flex_admin:*:#{resource_class.name.underscore}*"
      Rails.cache.delete_matched(pattern)
    end

    def invalidate_record_cache(record)
      # Invalidate all caches related to this record
      patterns = [
        "flex_admin:*:#{record.class.name.underscore}:#{record.id}*",
        "flex_admin:fragment:#{record.cache_key}*",
        "flex_admin:association:#{record.cache_key}*",
      ]

      patterns.each { |pattern| Rails.cache.delete_matched(pattern) }
    end

    # Cache statistics
    def cache_stats
      if Rails.cache.respond_to?(:stats)
        Rails.cache.stats
      elsif defined?(SolidCache)
        solid_cache_stats
      else
        {}
      end
    end

    # Cache cleanup
    def cleanup_expired_cache
      return unless defined?(SolidCache)

      SolidCache::Entry.where(expires_at: ...Time.current).delete_all
    end

    # Cache size monitoring
    def cache_size
      if defined?(SolidCache)
        SolidCache::Entry.sum(:byte_size)
      else
        0
      end
    end

    private

    def fragment_cache_key(record, fragment_name)
      "flex_admin:fragment:#{record.cache_key_with_version}/#{fragment_name}"
    end

    def association_count_cache_key(record, association_name)
      "flex_admin:association:#{record.cache_key}/#{association_name}_count"
    end

    def bulk_association_counts(records, association_name)
      return {} if records.empty?

      first_record = records.first
      association = first_record.class.reflect_on_association(association_name)

      return {} unless association

      case association.macro
      when :has_many, :has_and_belongs_to_many
        bulk_has_many_counts(records, association)
      when :has_one
        bulk_has_one_counts(records, association)
      else
        {}
      end
    end

    def bulk_has_many_counts(records, association)
      foreign_key = association.foreign_key
      associated_class = association.klass
      record_ids = records.map(&:id)

      counts = associated_class.where(foreign_key => record_ids)
        .group(foreign_key)
        .count

      # Ensure all records have a count (even if 0)
      record_ids.index_with do |id|
        counts[id] || 0
      end
    end

    def bulk_has_one_counts(records, association)
      foreign_key = association.foreign_key
      associated_class = association.klass
      record_ids = records.map(&:id)

      existing_ids = associated_class.where(foreign_key => record_ids)
        .pluck(foreign_key)
        .to_set

      record_ids.index_with do |id|
        existing_ids.include?(id) ? 1 : 0
      end
    end

    def solid_cache_stats
      return {} unless defined?(SolidCache)

      {
        entries_count: SolidCache::Entry.count,
        total_size: SolidCache::Entry.sum(:byte_size),
        expired_count: SolidCache::Entry.where(expires_at: ...Time.current).count,
      }
    end
  end
end
