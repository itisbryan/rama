# frozen_string_literal: true

source 'https://rubygems.org'

# Specify your gem's dependencies in rama.gemspec
gemspec

# Development dependencies (moved from gemspec per RuboCop guidelines)
group :development, :test do
  # Database adapters for testing
  gem 'pg', '~> 1.5'
  gem 'mysql2', '~> 0.5'
  gem 'sqlite3', '~> 1.6'

  # Rails for testing
  gem 'rails', '~> 8.0.0'

  # Testing framework
  gem 'capybara', '>= 3.0'
  gem 'database_cleaner-active_record', '>= 2.1'
  gem 'factory_bot_rails', '>= 6.0'
  gem 'rspec-rails', '>= 6.0'
  gem 'selenium-webdriver', '>= 4.0'

  # Code quality and linting
  gem 'rubocop', '>= 1.57'
  gem 'rubocop-performance', '>= 1.19'
  gem 'rubocop-rails', '>= 2.22'
  gem 'rubocop-rspec', '>= 2.25'

  # Security scanning
  gem 'brakeman', '>= 6.0'
  gem 'bundler-audit', '>= 0.9'

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
