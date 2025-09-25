# frozen_string_literal: true

require_relative 'lib/rama/version'

Gem::Specification.new do |spec|
  spec.name        = 'rama'
  spec.version     = Rama::VERSION
  spec.authors     = ['Rama Team']
  spec.email       = ['team@rama.dev']
  spec.homepage    = 'https://github.com/rama/rama'
  spec.summary     = 'Modern Rails 8 admin panel with visual builder'
  spec.description = 'A modern Rails 8 admin panel with visual builder, smart search, and high-performance features'
  spec.license     = 'MIT'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['changelog_uri'] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) {
    Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']
  }

  spec.require_paths = ['lib']

  # Rails 8 requirement
  spec.add_dependency 'rails', '>= 8.0.0'

  # Hotwire stack
  spec.add_dependency 'stimulus-rails', '>= 1.3'
  spec.add_dependency 'turbo-rails', '>= 2.0'

  # UI Components
  spec.add_dependency 'tailwindcss-rails', '>= 2.0'
  spec.add_dependency 'view_component', '>= 3.0'

  # Rails 8 Solid Suite
  spec.add_dependency 'solid_cable', '>= 1.0'
  spec.add_dependency 'solid_cache', '>= 1.0'
  spec.add_dependency 'solid_queue', '>= 1.0'

  # Search and filtering
  spec.add_dependency 'pg_search', '>= 2.3'
  spec.add_dependency 'ransack', '>= 4.0'

  # Authorization
  spec.add_dependency 'cancancan', '>= 3.5'

  # Pagination
  spec.add_dependency 'pagy', '>= 6.0'

  # File uploads
  spec.add_dependency 'image_processing', '>= 1.2'

  # Development dependencies are specified in Gemfile per RuboCop guidelines

  spec.required_ruby_version = '>= 3.1.0'
end
