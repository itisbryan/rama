# frozen_string_literal: true

# Coverage reporting
if ENV['COVERAGE']
  require 'simplecov'
  require 'simplecov-lcov'

  SimpleCov::Formatter::LcovFormatter.config do |c|
    c.report_with_single_file = true
    c.single_report_path = 'coverage/lcov/rama.lcov'
  end

  SimpleCov.formatters = [
    SimpleCov::Formatter::HTMLFormatter,
    SimpleCov::Formatter::LcovFormatter,
  ]

  SimpleCov.start 'rails' do
    add_filter '/spec/'
    add_filter '/examples/'
    add_filter '/vendor/'
    add_filter '/bin/'

    add_group 'Controllers', 'app/controllers'
    add_group 'Models', 'app/models'
    add_group 'Components', 'app/components'
    add_group 'Jobs', 'app/jobs'
    add_group 'Libraries', 'lib'
  end
end

require 'bundler/setup'
require 'rails'
require 'rspec/rails'
require 'factory_bot_rails'
require 'capybara/rspec'
require 'selenium-webdriver'
require 'database_cleaner/active_record'

# Configure Capybara
Capybara.register_driver :headless_chrome do |_app|
  options = Selenium::WebDriver::Chrome::Options.new
  options.add_argument('--headless')
  options.add_argument('--no-sandbox')
  options.add_argument('--disable-dev-shm-usage')
  options.add_argument('--window-size=1400,1400')

  Selenium::WebDriver.for(:chrome, options: options)
end

Capybara.javascript_driver = :headless_chrome
Capybara.default_max_wait_time = 5

# Load the dummy Rails app for testing
require_relative 'dummy/config/environment'

# Load Rama
require 'rama'

# Load support files
Dir[File.expand_path('support/**/*.rb', __dir__)].each { |f| require f }

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Rama::TestHelpers
  config.include Capybara::DSL, type: :feature
  config.include Capybara::RSpecMatchers, type: :feature

  # Database cleaner
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around do |example|
    DatabaseCleaner.cleaning do
      example.run
    end
  end

  # Use transactional fixtures for non-JS tests
  config.use_transactional_fixtures = true

  # For JS tests, use database cleaner
  config.before(:each, :js) do
    DatabaseCleaner.strategy = :truncation
  end

  config.after(:each, :js) do
    DatabaseCleaner.strategy = :transaction
  end

  # Configure expectations
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.disable_monkey_patching!
  config.warnings = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed
end
