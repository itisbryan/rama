# frozen_string_literal: true

module Rama
  class Engine < ::Rails::Engine
    isolate_namespace Rama
    
    config.generators do |g|
      g.test_framework :rspec
      g.fixture_replacement :factory_bot
      g.assets false
      g.helper false
    end
    
    # Configure Rails 8 Solid Suite
    initializer "rama.configure_solid_suite" do |app|
      # Configure SolidQueue as default job backend
      app.config.active_job.queue_adapter = :solid_queue

      # Configure SolidCache as default cache store
      app.config.cache_store = :solid_cache_store

      # Configure SolidCable as default ActionCable adapter
      app.config.action_cable.adapter = :solid_cable
    end

    # Configure Hotwire
    initializer "rama.configure_hotwire" do |app|
      # Ensure Turbo and Stimulus are loaded
      app.config.importmap.draw do
        pin "turbo", to: "turbo.min.js"
        pin "stimulus", to: "stimulus.min.js"
        pin "stimulus-loading", to: "stimulus-loading.js"
        pin_all_from "app/javascript/rama/controllers", under: "rama/controllers"
      end
    end
    
    # Configure ViewComponent
    initializer "rama.configure_view_component" do |app|
      app.config.view_component.preview_paths << Engine.root.join("spec/components/previews")
      app.config.view_component.default_preview_layout = "rama/component_preview"
    end

    # Configure assets
    initializer "rama.assets" do |app|
      app.config.assets.precompile += %w[
        rama/application.css
        rama/application.js
      ]
    end

    # Configure routes
    initializer "rama.routes" do |app|
      app.routes.prepend do
        mount Rama::Engine => "/admin", as: :rama
      end
    end
    
    # Load field types
    config.to_prepare do
      Dir[Engine.root.join("app/field_types/**/*.rb")].each { |f| require f }
    end
  end
end
