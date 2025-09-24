# Rama - Modern Rails 8 Admin Panel

A modern admin panel for Rails 8 applications with visual builder, smart search, and high-performance features using the Solid suite.

## Features

### 🏗️ Core Framework
- **Rails 8 Native**: Built specifically for Rails 8 with Solid suite integration
- **Hotwire Powered**: Real-time updates with Turbo and Stimulus
- **Component Architecture**: ViewComponent-based UI with Tailwind CSS
- **Flexible Authentication**: Support for Devise, basic auth, or custom solutions
- **Authorization Ready**: CanCanCan and Pundit integration

### 🎨 Visual Builder System
- **Drag & Drop Form Builder**: Create admin forms visually without coding
- **Query Builder**: Visual SQL query construction with live preview
- **Dashboard Builder**: Custom dashboard creation with widgets
- **Real-time Collaboration**: Multiple users can edit simultaneously
- **Configuration Export**: Export/import configurations as code

### 🔍 Advanced Search & Filtering
- **Multi-Strategy Search**: Full-text, trigram, and basic search with auto-selection
- **Complex Filters**: Date ranges, multi-select, nested attributes
- **Smart Filter UI**: Saved filters, presets, and real-time updates
- **Association Search**: Deep searching across model relationships
- **Performance Optimized**: Intelligent indexing and query optimization

### ⚡ Performance Framework
- **Cursor Pagination**: Scales to millions of records without COUNT queries
- **Virtual Scrolling**: Smooth navigation through large datasets
- **Intelligent Caching**: Multi-layer caching with SolidCache
- **Query Optimization**: Automatic N+1 prevention and smart includes
- **Performance Monitoring**: Real-time tracking and alerting

### 🚀 Enterprise Features
- **Bulk Operations**: Memory-efficient bulk updates, deletes, and exports
- **Custom Field Types**: Extensible field system with rich widgets
- **API Integration**: REST endpoints and webhook support
- **Plugin System**: Modular architecture for extensions
- **Security Features**: Audit logging, encryption, and compliance

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rama'
```

And then execute:

```bash
$ bundle install
$ rails generate rama:install
$ rails db:migrate
```

## Quick Start

### 1. Configure Rama

```ruby
# config/initializers/rama.rb
Rama.configure do |config|
  config.app_name = "My Admin Panel"
  config.authenticate_with :devise
  config.authorize_with :cancancan
  
  # Rails 8 Solid Suite (enabled by default)
  config.solid_suite(
    queue: true,    # Use SolidQueue for background jobs
    cache: true,    # Use SolidCache for caching
    cable: true     # Use SolidCable for WebSockets
  )
  
  # Performance settings
  config.pagination(per_page: 25, max_per_page: 100)
  config.search(strategy: :auto)
  config.performance_monitoring(enabled: Rails.env.production?)
  
  # Visual builder
  config.visual_builder(enabled: true, collaboration: true)
end
```

### 2. Define Admin Resources

Rama provides an intuitive, readable DSL for defining admin resources:

```ruby
# app/admin/user_resource.rb
class UserResource < Rama::Resource
  # === BASIC CONFIGURATION ===
  title "User Management"
  description "Manage system users and their permissions"
  model User
  icon "users"

  # === DISPLAY FIELDS ===
  display do
    show :name, as: :text, required: true do
      searchable
      sortable
      link_to { |user| admin_user_path(user) }
    end

    show :email, as: :email, required: true do
      searchable
      help_text "User's primary email address"
    end

    show :role, as: :badge do
      options User.roles.keys
      color_map(admin: :red, manager: :blue, user: :green)
    end

    show :active, as: :status_badge do
      true_label "Active"
      false_label "Inactive"
    end

    show :orders_count, as: :counter do
      count_of :orders
      link_to { |user| admin_orders_path(user_id: user.id) }
    end
  end

  # === FILTERING ===
  filters do
    text :name, :email
    select :role, options: User.roles.keys
    boolean :active, labels: { true: "Active", false: "Inactive" }
    date_range :created_at, label: "Join Date"
  end

  # === SEARCH CONFIGURATION ===
  search do
    strategy :full_text
    fields :name, :email
    highlight_matches true
  end

  # === ACTIONS ===
  actions do
    bulk :activate, label: "Activate Selected" do
      update active: true
      success_message "Users activated successfully"
    end

    row :impersonate, icon: "user-switch", label: "Login as User" do
      condition { |user| current_user.admin? && user.active? }
    end
  end

  # === PERFORMANCE ===
  performance do
    paginate_with :cursor, per_page: 25
    includes :profile, :company
    cache_counts_for :orders, :reviews
  end

  # === PERMISSIONS ===
  permissions do
    allow :read, for: :all
    allow :create, for: [:admin, :manager]
    allow :update, for: :user, condition: :own_record?
    allow :delete, for: :admin, condition: :not_self?
  end
end
```

### 3. Register Resources

```ruby
# config/initializers/rama.rb
Rama.register_resource(:users, UserResource)
Rama.register_resource(:orders, OrderResource)
Rama.register_resource(:products, ProductResource)
```

### 4. Mount Routes

```ruby
# config/routes.rb
Rails.application.routes.draw do
  mount Rama::Engine => "/admin", as: :admin
  # your other routes
end
```

## Visual Builder Usage

### Form Builder

1. Navigate to `/admin/builder/forms`
2. Click "New Form" 
3. Drag fields from the palette to the canvas
4. Configure field properties in the sidebar
5. Preview the form in real-time
6. Save and deploy to production

### Query Builder

1. Go to `/admin/builder/queries`
2. Select tables and join conditions visually
3. Add filters and sorting
4. Preview results in real-time
5. Save queries for reuse

### Dashboard Builder

1. Visit `/admin/builder/dashboards`
2. Drag widgets onto the canvas
3. Resize and position widgets
4. Configure data sources
5. Publish dashboard

## Performance Features

### Cursor Pagination

```ruby
# Automatically handles large datasets
users = User.admin_scope.cursor_paginate(
  cursor: params[:cursor],
  limit: 50
)
```

### Intelligent Caching

```ruby
# Automatic caching with SolidCache
Rama::CacheManager.cache_page("users_index") do
  User.includes(:orders).limit(50)
end
```

### Search Optimization

```ruby
# Multi-strategy search with auto-selection
search_engine = Rama::SearchEngine.new(User, "john doe")
results = search_engine.search # Automatically chooses best strategy
```

## Customization

### Custom Field Types

```ruby
class SignaturePadField < Rama::FieldTypes::BaseField
  def form_input_type
    :signature_pad
  end
  
  def display_value(record)
    image_tag(record.public_send(name), size: "100x50") if record.public_send(name).present?
  end
end

Rama.register_field_type(:signature_pad, SignaturePadField)
```

### Custom Components

```ruby
class CustomTableComponent < Rama::TableComponent
  private
  
  def custom_cell_renderer(record, column)
    # Your custom rendering logic
  end
end
```

### Plugins

```ruby
# lib/rama/plugins/analytics_plugin.rb
module Rama
  module Plugins
    class AnalyticsPlugin
      def self.install
        # Plugin installation logic
      end
    end
  end
end
```

## API Usage

### REST API

```ruby
# GET /admin/api/v1/users
# POST /admin/api/v1/users
# PUT /admin/api/v1/users/:id
# DELETE /admin/api/v1/users/:id

# With authentication
headers = { 'Authorization' => 'Bearer your-token' }
response = HTTParty.get('/admin/api/v1/users', headers: headers)
```

### WebSocket Integration

```javascript
// Real-time updates
const cable = ActionCable.createConsumer('/admin/cable')
cable.subscriptions.create('AdminNotificationsChannel', {
  received(data) {
    // Handle real-time updates
  }
})
```

## Performance Benchmarks

- **Page Load**: < 500ms for 1M+ records
- **Search**: < 300ms for complex queries
- **Memory**: < 50MB per request
- **Concurrency**: 100+ simultaneous users
- **Bulk Operations**: 10K+ records/minute

## Requirements

- Ruby 3.1+
- Rails 8.0+
- PostgreSQL 12+ (recommended) or MySQL 8+
- Redis (optional, for non-Solid suite setups)

## Development

### Code Quality

Rama uses comprehensive linting and quality checks:

```bash
# Run RuboCop linting
bundle exec rubocop

# Auto-fix RuboCop issues
bundle exec rubocop -A

# Run security checks
bundle exec brakeman
bundle exec bundle-audit

# Run all quality checks
rake quality:all
```

### Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test types
bin/test --unit           # Unit tests only
bin/test --integration    # Integration tests only
bin/test --performance    # Performance tests only
bin/test --coverage      # With coverage report
```

### Pre-commit Hooks

Install pre-commit hooks to catch issues early:

```bash
pip install pre-commit
pre-commit install
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run quality checks (`rake quality:all`)
4. Run tests (`bundle exec rspec`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### CI/CD

The project uses GitHub Actions for:
- ✅ **Code Quality**: RuboCop linting with Rails/RSpec extensions
- ✅ **Security**: Brakeman and bundle-audit scanning
- ✅ **Testing**: Multi-version Ruby/Rails/Database matrix
- ✅ **Coverage**: SimpleCov with Codecov reporting
- ✅ **Releases**: Automated gem publishing

See [CI_SETUP.md](CI_SETUP.md) for detailed CI/CD documentation.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Support

- Documentation: [https://flexadmin.dev/docs](https://flexadmin.dev/docs)
- Issues: [GitHub Issues](https://github.com/flexadmin/rama/issues)
- Discussions: [GitHub Discussions](https://github.com/flexadmin/rama/discussions)
- Email: support@flexadmin.dev
