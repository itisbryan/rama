# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

# RSpec tasks
RSpec::Core::RakeTask.new(:spec) do |t|
  t.exclude_pattern = 'spec/performance/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:spec_performance) do |t|
  t.pattern = 'spec/performance/**/*_spec.rb'
end

RSpec::Core::RakeTask.new(:spec_all) do |t|
  # Run all specs including performance tests
end

# RuboCop tasks
RuboCop::RakeTask.new

# Custom tasks for testing
namespace :test do
  desc 'Run unit tests'
  task unit: :spec

  desc 'Run integration tests'
  task :integration do
    system('bundle exec rspec spec/features/')
  end

  desc 'Run performance tests'
  task performance: :spec_performance

  desc 'Run all tests'
  task all: [:spec_all, :rubocop]

  desc 'Setup test database'
  task :setup do
    puts 'Setting up test database...'
    system('cd spec/dummy && rails db:create db:migrate RAILS_ENV=test')
  end

  desc 'Reset test database'
  task :reset do
    puts 'Resetting test database...'
    system('cd spec/dummy && rails db:drop db:create db:migrate RAILS_ENV=test')
  end

  desc 'Run tests with coverage'
  task :coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task['test:all'].invoke
  end
end

# Demo tasks
namespace :demo do
  desc 'Setup demo application'
  task :setup do
    puts 'Setting up demo application...'
    system('rails new demo_app --skip-test --skip-system-test')
    
    Dir.chdir('demo_app') do
      # Add Rama to Gemfile
      File.open('Gemfile', 'a') do |f|
        f.puts "\ngem 'rama', path: '..'"
      end
      
      system('bundle install')
      system('rails generate rama:install')
      system('rails db:create db:migrate')
      
      # Create sample data
      system('rails runner "
        User.create!(name: \"Admin User\", email: \"admin@example.com\", role: \"admin\")
        10.times { |i| User.create!(name: \"User #{i}\", email: \"user#{i}@example.com\") }
        puts \"Demo data created!\"
      "')
    end
    
    puts 'Demo application ready! Run: cd demo_app && rails server'
  end

  desc 'Clean demo application'
  task :clean do
    system('rm -rf demo_app')
    puts 'Demo application cleaned'
  end
end

# Benchmark tasks
namespace :benchmark do
  desc 'Run pagination benchmarks'
  task :pagination do
    require_relative 'spec/spec_helper'
    
    puts 'Running pagination benchmarks...'
    
    # Create test data
    User.delete_all
    1000.times { |i| User.create!(name: "User #{i}", email: "user#{i}@example.com") }
    
    require 'benchmark'
    
    Benchmark.bm(20) do |x|
      x.report('Cursor pagination:') do
        paginator = Rama::Pagination::CursorPaginator.new(User.order(:created_at), limit: 50)
        10.times { paginator.paginate }
      end
      
      x.report('Offset pagination:') do
        paginator = Rama::Pagination::OffsetPaginator.new(User.order(:created_at), per_page: 50)
        10.times { |i| paginator = Rama::Pagination::OffsetPaginator.new(User.order(:created_at), page: i + 1, per_page: 50); paginator.paginate }
      end
    end
  end

  desc 'Run search benchmarks'
  task :search do
    require_relative 'spec/spec_helper'
    
    puts 'Running search benchmarks...'
    
    # Create test data
    User.delete_all
    1000.times { |i| User.create!(name: "Test User #{i}", email: "user#{i}@example.com") }
    
    require 'benchmark'
    
    Benchmark.bm(20) do |x|
      x.report('Basic search:') do
        engine = Rama::SearchEngine.new(User, 'Test User', strategy: :basic)
        10.times { engine.search.limit(50).to_a }
      end
      
      if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
        x.report('Trigram search:') do
          engine = Rama::SearchEngine.new(User, 'Test User', strategy: :trigram)
          10.times { engine.search.limit(50).to_a }
        end
      end
    end
  end
end

# Documentation tasks
namespace :docs do
  desc 'Generate documentation'
  task :generate do
    system('yard doc')
    puts 'Documentation generated in doc/'
  end

  desc 'Serve documentation'
  task :serve do
    system('yard server --reload')
  end
end

# Quality tasks
namespace :quality do
  desc 'Run RuboCop'
  task :rubocop do
    system('bundle exec rubocop')
  end

  desc 'Run RuboCop with auto-correct'
  task :rubocop_fix do
    system('bundle exec rubocop -A')
  end

  desc 'Run security checks'
  task :security do
    puts 'Running Brakeman security scan...'
    system('bundle exec brakeman --no-pager')

    puts 'Running bundle audit...'
    system('bundle exec bundle-audit update && bundle exec bundle-audit')
  end

  desc 'Run all quality checks'
  task all: [:rubocop, :security]
end

# CI tasks
namespace :ci do
  desc 'Run full CI suite'
  task :all do
    puts 'Running RuboCop...'
    exit(1) unless system('bundle exec rubocop')

    puts 'Running security checks...'
    exit(1) unless system('bundle exec brakeman --exit-on-warn --no-pager')
    exit(1) unless system('bundle exec bundle-audit update && bundle exec bundle-audit')

    puts 'Running tests...'
    exit(1) unless system('bundle exec rspec')

    puts 'All CI checks passed!'
  end
end

# Default task
task default: ['quality:rubocop', 'test:all']

# Load Rails tasks if in Rails environment
begin
  require 'rails/tasks'
rescue LoadError
  # Not in Rails environment
end
