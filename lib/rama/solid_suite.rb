# frozen_string_literal: true

module Rama
  module SolidSuite
    extend ActiveSupport::Concern
    
    class_methods do
      def configure_solid_suite!
        configure_solid_queue! if Rama.config.solid_queue_enabled
        configure_solid_cache! if Rama.config.solid_cache_enabled
        configure_solid_cable! if Rama.config.solid_cable_enabled
      end
      
      private
      
      def configure_solid_queue!
        return unless defined?(SolidQueue)
        
        Rails.application.config.active_job.queue_adapter = :solid_queue
        
        # Configure SolidQueue settings
        SolidQueue.configure do |config|
          config.connects_to = { database: { writing: :primary } }
          config.use_skip_locked = true
          config.silence_polling = true
        end
      end
      
      def configure_solid_cache!
        return unless defined?(SolidCache)
        
        Rails.application.config.cache_store = :solid_cache_store
        
        # Configure SolidCache settings
        Rails.application.config.solid_cache.connects_to = { database: { writing: :primary } }
        Rails.application.config.solid_cache.encrypt = Rails.env.production?
      end
      
      def configure_solid_cable!
        return unless defined?(SolidCable)
        
        Rails.application.config.action_cable.adapter = :solid_cable
        
        # Configure SolidCable settings
        Rails.application.config.solid_cable.connects_to = { database: { writing: :primary } }
        Rails.application.config.solid_cable.message_retention = 1.day
      end
    end
    
    # Job management utilities
    module JobManager
      def self.queue_stats
        return {} unless defined?(SolidQueue)
        
        {
          total_jobs: SolidQueue::Job.count,
          pending_jobs: SolidQueue::Job.where(finished_at: nil).count,
          failed_jobs: SolidQueue::Job.joins(:failed_execution).count,
          completed_jobs: SolidQueue::Job.where.not(finished_at: nil).count
        }
      end
      
      def self.recent_jobs(limit: 50)
        return [] unless defined?(SolidQueue)
        
        SolidQueue::Job.includes(:execution)
                       .order(created_at: :desc)
                       .limit(limit)
      end
      
      def self.retry_failed_job(job_id)
        return false unless defined?(SolidQueue)
        
        job = SolidQueue::Job.find(job_id)
        job.retry if job.failed_execution
      end
      
      def self.clear_completed_jobs(older_than: 1.week.ago)
        return 0 unless defined?(SolidQueue)
        
        SolidQueue::Job.where(finished_at: ...older_than).delete_all
      end
    end
    
    # Cache management utilities
    module CacheManager
      def self.cache_stats
        return {} unless Rails.cache.respond_to?(:stats)
        
        Rails.cache.stats
      end
      
      def self.clear_cache(pattern: nil)
        if pattern
          Rails.cache.delete_matched(pattern)
        else
          Rails.cache.clear
        end
      end
      
      def self.cache_size
        return 0 unless defined?(SolidCache)
        
        SolidCache::Entry.sum(:byte_size)
      end
      
      def self.cleanup_expired_cache
        return 0 unless defined?(SolidCache)
        
        SolidCache::Entry.where('expires_at < ?', Time.current).delete_all
      end
    end
    
    # Cable management utilities
    module CableManager
      def self.connection_stats
        return {} unless defined?(SolidCable)
        
        {
          total_connections: SolidCable::Message.distinct.count(:connection_identifier),
          total_messages: SolidCable::Message.count,
          recent_messages: SolidCable::Message.where(created_at: 1.hour.ago..).count
        }
      end
      
      def self.cleanup_old_messages(older_than: 1.day.ago)
        return 0 unless defined?(SolidCable)
        
        SolidCable::Message.where(created_at: ...older_than).delete_all
      end
      
      def self.broadcast_to_admin_users(message)
        return unless defined?(SolidCable)
        
        ActionCable.server.broadcast("admin_notifications", message)
      end
    end
  end
end
