# Testing Rama

This guide covers how to test the Rama library comprehensively, including unit tests, integration tests, performance tests, and manual testing strategies.

## Quick Start

```bash
# Install dependencies
bundle install

# Setup test database
rake test:setup

# Run all tests
bin/test

# Run specific test types
bin/test --unit           # Unit tests only
bin/test --integration    # Integration tests only
bin/test --performance    # Performance tests only
bin/test --fast          # All except performance tests
bin/test --coverage      # With coverage report
```

## Test Structure

```
spec/
├── spec_helper.rb              # Main test configuration
├── support/
│   └── test_helpers.rb         # Custom test helpers
├── factories/
│   └── users.rb               # FactoryBot factories
├── lib/                       # Unit tests for library code
│   ├── rama/
│   │   ├── resource_spec.rb
│   │   ├── search_engine_spec.rb
│   │   └── pagination_spec.rb
├── features/                  # Integration tests (Capybara)
│   ├── admin_dashboard_spec.rb
│   └── visual_builder_spec.rb
├── performance/               # Performance tests
│   └── pagination_performance_spec.rb
└── dummy/                     # Test Rails application
    └── config/
        └── environment.rb
```

## Test Categories

### 1. Unit Tests (`spec/lib/`)

Test individual components in isolation:

```ruby
# Example: Testing the Resource DSL
RSpec.describe Rama::Resource do
  it 'allows defining fields with types and options' do
    resource_class = Class.new(described_class) do
      model User
      field :name, :string, searchable: true, required: true
      field :email, :email, searchable: true
    end

    expect(resource_class.fields.keys).to include(:name, :email)
    expect(resource_class.fields[:name][:type]).to eq(:string)
  end
end
```

**Run unit tests:**
```bash
bin/test --unit
# or
bundle exec rspec spec/lib/
```

### 2. Integration Tests (`spec/features/`)

Test complete user workflows using Capybara:

```ruby
# Example: Testing the admin dashboard
RSpec.describe 'Admin Dashboard', type: :feature, js: true do
  it 'allows searching users' do
    user = create(:user, name: 'John Doe')
    
    visit '/admin/users'
    fill_in 'Search', with: 'John'
    click_button 'Search'
    
    expect(page).to have_content('John Doe')
  end
end
```

**Run integration tests:**
```bash
bin/test --integration
# or
bundle exec rspec spec/features/
```

### 3. Performance Tests (`spec/performance/`)

Test performance characteristics with large datasets:

```ruby
# Example: Testing pagination performance
RSpec.describe 'Pagination Performance', type: :performance do
  before do
    create_large_dataset(User, count: 10_000)
  end

  it 'paginates efficiently without COUNT queries' do
    performance = measure_performance do
      paginator = Rama::Pagination::CursorPaginator.new(User.all, limit: 50)
      result = paginator.paginate
    end
    
    expect(performance[:duration]).to be < 100.milliseconds
  end
end
```

**Run performance tests:**
```bash
bin/test --performance
# or
bundle exec rspec spec/performance/
```

## Testing Different Components

### Testing Resource Configuration

```ruby
# Test field definitions
resource_class = Class.new(Rama::Resource) do
  model User
  field :name, :string, searchable: true
  field :orders_count, :has_many_count, association: :orders
end

# Test query building
scope = resource_class.build_scope({ active: true })
expect(scope.where_values_hash).to include('active' => true)

# Test field formatting
user = create(:user, :with_orders)
count = resource_class.format_field_value(user, :orders_count)
expect(count).to eq(user.orders.count)
```

### Testing Search Engine

```ruby
# Test different search strategies
search_engine = Rama::SearchEngine.new(User, 'John Doe', strategy: :basic)
results = search_engine.search
expect(results).to include(user_named_john)

# Test auto-strategy selection
search_engine = Rama::SearchEngine.new(User, 'Jo', strategy: :auto)
expect(search_engine.send(:strategy)).to eq(:basic) # Short query uses basic

# Test suggestions
suggestions = search_engine.suggestions(limit: 5)
expect(suggestions).to include('John Doe')
```

### Testing Visual Builder

```ruby
# Test form configuration
form = create(:form_configuration, :with_fields)
expect(form.ordered_fields.count).to eq(3)

# Test field reordering
form.move_field(field.id, 0)
expect(form.ordered_fields.first).to eq(field)

# Test drag and drop (JavaScript)
visit "/admin/builder/forms/#{form.id}"
simulate_drag_and_drop('[data-field-type="string"]', '[data-canvas]')
expect(page).to have_css('[data-field-type="string"]', count: 2)
```

### Testing Performance Features

```ruby
# Test cursor pagination
paginator = Rama::Pagination::CursorPaginator.new(User.all, limit: 50)
result = paginator.paginate

expect(result[:records].size).to eq(50)
expect(result[:has_next_page]).to be true
expect(result[:next_cursor]).to be_present

# Test caching
with_caching_enabled do
  Rama::CacheManager.cache_page("test_key") { "cached_value" }
  expect_cache_hit("rama:page:test_key")
end

# Test bulk operations
job = Rama::BulkOperationJob.new
expect { 
  job.perform('update', 'User', {}, { attributes: { active: false } }, user.id)
}.to change { User.where(active: false).count }
```

## Test Helpers

### Authentication Helpers

```ruby
# Sign in an admin user for tests
admin_user = sign_in_admin_user
expect(admin_user.role).to eq('admin')

# Test with different user roles
regular_user = sign_in_admin_user(create(:user))
expect(regular_user.role).to eq('user')
```

### Performance Helpers

```ruby
# Measure performance
performance = measure_performance do
  # Your code here
end

expect(performance[:duration]).to be < 1.second
expect(performance[:memory_used]).to be < 50.megabytes

# Create large datasets
create_large_dataset(User, count: 1000)
expect(User.count).to eq(1000)
```

### Cache Helpers

```ruby
# Test caching behavior
with_caching_enabled do
  result = expensive_operation
  expect_cache_hit("cache_key")
end

# Clear cache between tests
clear_rama_cache
```

### Turbo Helpers

```ruby
# Wait for Turbo operations
click_button 'Submit'
wait_for_turbo
expect(page).to have_content('Success')

# Wait for specific Turbo frames
wait_for_turbo_frame('modal')
expect(page).to have_css('turbo-frame#modal')
```

## Running Tests

### Basic Commands

```bash
# All tests
bundle exec rspec

# Specific file
bundle exec rspec spec/lib/rama/resource_spec.rb

# Specific test
bundle exec rspec spec/lib/rama/resource_spec.rb:25

# With tags
bundle exec rspec --tag js
bundle exec rspec --tag ~performance  # Exclude performance tests
```

### Using the Test Script

```bash
# Fast tests (good for development)
bin/test --fast

# Full test suite
bin/test

# With coverage
bin/test --coverage

# Verbose output
bin/test --verbose
```

### Continuous Integration

```yaml
# .github/workflows/test.yml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:13
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v2
      - uses: ruby/setup-ruby@v1
        with:
          bundler-cache: true
      - name: Setup database
        run: |
          bundle exec rake test:setup
        env:
          DATABASE_URL: postgres://postgres:postgres@localhost:5432/rama_test
      - name: Run tests
        run: bin/test --coverage
```

## Manual Testing

### Demo Application

```bash
# Create demo app
rake demo:setup

# Start demo server
cd demo_app && rails server

# Visit http://localhost:3000/admin
```

### Testing Checklist

**Core Functionality:**
- [ ] Resource CRUD operations work
- [ ] Search finds correct records
- [ ] Filters apply correctly
- [ ] Pagination works with large datasets
- [ ] Authentication/authorization enforced

**Visual Builder:**
- [ ] Drag and drop creates fields
- [ ] Field properties can be edited
- [ ] Forms can be saved and loaded
- [ ] Real-time preview updates
- [ ] Export/import works

**Performance:**
- [ ] Page loads < 500ms with 1M+ records
- [ ] Search responds < 300ms
- [ ] Memory usage < 50MB per request
- [ ] Bulk operations handle 10K+ records

**Browser Compatibility:**
- [ ] Chrome (latest)
- [ ] Firefox (latest)
- [ ] Safari (latest)
- [ ] Edge (latest)
- [ ] Mobile browsers

## Debugging Tests

### Common Issues

**Database Issues:**
```bash
# Reset test database
rake test:reset

# Check database exists
ls spec/dummy/db/test.sqlite3
```

**JavaScript Issues:**
```ruby
# Add debugging to feature tests
save_and_open_page  # Opens browser
save_screenshot     # Saves screenshot

# Check console errors
page.driver.browser.manage.logs.get(:browser)
```

**Performance Issues:**
```ruby
# Add detailed timing
puts Benchmark.measure { your_code_here }

# Check SQL queries
ActiveRecord::Base.logger = Logger.new(STDOUT)
```

### Test Data

```ruby
# Create specific test scenarios
user_with_many_orders = create(:user, :with_orders)
inactive_users = create_list(:user, 5, active: false)
admin_user = create(:admin_user)

# Use traits for variations
create(:user, :admin, :with_profile)
```

This comprehensive testing strategy ensures Rama works correctly across all scenarios, performs well under load, and provides a great user experience.
