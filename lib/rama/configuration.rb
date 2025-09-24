# frozen_string_literal: true

class Rama::Configuration
  attr_accessor :app_name, :authentication_method, :authorization_method,
                :default_per_page, :max_per_page, :cache_enabled,
                :solid_queue_enabled, :solid_cache_enabled, :solid_cable_enabled,
                :search_strategy, :performance_monitoring_enabled,
                :visual_builder_enabled, :collaboration_enabled

  def initialize
    @app_name = 'Rama'
    @authentication_method = :devise
    @authorization_method = :cancancan
    @default_per_page = 25
    @max_per_page = 100
    @cache_enabled = true
    @solid_queue_enabled = true
    @solid_cache_enabled = true
    @solid_cable_enabled = true
    @search_strategy = :auto
    @performance_monitoring_enabled = Rails.env.production?
    @visual_builder_enabled = true
    @collaboration_enabled = true
  end

  def authenticate_with(method)
    @authentication_method = method
  end

  def authorize_with(method)
    @authorization_method = method
  end

  def pagination(per_page: 25, max_per_page: 100)
    @default_per_page = per_page
    @max_per_page = max_per_page
  end

  def solid_suite(queue: true, cache: true, cable: true)
    @solid_queue_enabled = queue
    @solid_cache_enabled = cache
    @solid_cable_enabled = cable
  end

  def search(strategy: :auto)
    @search_strategy = strategy
  end

  def performance_monitoring(enabled: Rails.env.production?)
    @performance_monitoring_enabled = enabled
  end

  def visual_builder(enabled: true, collaboration: true)
    @visual_builder_enabled = enabled
    @collaboration_enabled = collaboration
  end
end
