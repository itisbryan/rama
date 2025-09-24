# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in rama.gemspec
gemspec

# Development dependencies that aren't in gemspec
group :development, :test do
  # Database adapters for testing
  gem 'pg', '~> 1.5'
  gem 'mysql2', '~> 0.5'
  gem 'sqlite3', '~> 1.6'
  
  # Rails for testing
  gem 'rails', '~> 8.0.0'
  
  # Additional development tools
  gem 'pry', '~> 0.14'
  gem 'pry-rails', '~> 0.3'
  gem 'listen', '~> 3.8'
  
  # Documentation
  gem 'yard', '~> 0.9'
  gem 'redcarpet', '~> 3.6' # For YARD markdown support
end

group :test do
  # Coverage reporting
  gem 'simplecov', '~> 0.21.2', require: false
  gem 'simplecov-lcov', '~> 0.8', require: false
end
