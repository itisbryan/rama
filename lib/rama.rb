# frozen_string_literal: true

require 'rails'
require 'turbo-rails'
require 'stimulus-rails'
require 'view_component'
require 'tailwindcss-rails'
require 'solid_queue'
require 'solid_cache'
require 'solid_cable'
require 'ransack'
require 'pg_search'
require 'cancancan'
require 'pagy'
require 'image_processing'

require 'rama/version'
require 'rama/engine'
require 'rama/configuration'
require 'rama/resource'
require 'rama/field_types'
require 'rama/search_engine'
require 'rama/cache_manager'
require 'rama/query_optimizer'
require 'rama/pagination'

module Rama
  class Error < StandardError; end

  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def config
      configuration || configure
    end

    # Resource registry
    def resources
      @resources ||= {}
    end

    def register_resource(name, resource_class)
      resources[name.to_s] = resource_class
    end

    def find_resource(name)
      resources[name.to_s]
    end

    # Field type registry
    def field_types
      @field_types ||= {}
    end

    def register_field_type(name, field_class)
      field_types[name.to_s] = field_class
    end

    def find_field_type(name)
      field_types[name.to_s] || FieldTypes::StringField
    end
  end
end
