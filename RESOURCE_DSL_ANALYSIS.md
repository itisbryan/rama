# Rama Resource DSL Analysis & Improvements

## Current Resource Definition Issues

### 1. **Verbose and Repetitive**
```ruby
# Current approach - lots of repetition
field :name, :string, searchable: true, required: true
field :email, :email, searchable: true, required: true
field :role, :select, collection: User.roles.keys
filter :role, :select, collection: User.roles.keys  # Duplicate definition
```

### 2. **Mixed Concerns**
```ruby
# Fields, filters, search, performance, and authorization all mixed together
class UserResource < Rama::Resource
  field :name, :string
  filter :name, :string
  search fields: [:name]
  performance do
    includes :profile
  end
  authorize do
    can :read, User
  end
end
```

### 3. **Not Self-Documenting**
```ruby
# What does this actually do?
field :orders_count, :has_many_count, association: :orders
performance do
  cache_association_counts :orders, :reviews
end
```

### 4. **Complex Authorization Syntax**
```ruby
# Hard to read authorization rules
authorize do
  can :read, User
  can :create, User, if: -> { current_user.admin? }
  can :update, User, if: -> { current_user.admin? || current_user == resource }
  can :destroy, User, if: -> { current_user.admin? && current_user != resource }
end
```

## Proposed Improved DSL

### 1. **Grouped and Semantic Sections**

```ruby
class UserResource < Rama::Resource
  # === BASIC CONFIGURATION ===
  title "User Management"
  description "Manage system users and their permissions"
  model User
  icon "users"
  
  # === DISPLAY FIELDS ===
  display do
    show :id, as: :number, label: "ID"
    show :name, as: :text, required: true do
      searchable
      sortable
      link_to { |user| admin_user_path(user) }
    end
    
    show :email, as: :email, required: true do
      searchable
      validate :email_format
      help_text "User's primary email address"
    end
    
    show :role, as: :badge do
      options User.roles.keys
      color_map(
        admin: :red,
        manager: :blue,
        user: :green
      )
    end
    
    show :active, as: :status_badge do
      true_label "Active"
      false_label "Inactive"
    end
    
    show :created_at, as: :datetime, label: "Joined"
    
    show :orders_count, as: :counter do
      count_of :orders
      link_to { |user| admin_orders_path(user_id: user.id) }
    end
  end
  
  # === FILTERING ===
  filters do
    by :name, using: :text_search
    by :email, using: :text_search
    by :role, using: :select, options: User.roles.keys
    by :active, using: :boolean, labels: { true: "Active", false: "Inactive" }
    by :created_at, using: :date_range, label: "Join Date"
    by :orders_count, using: :number_range, label: "Number of Orders"
  end
  
  # === SEARCH CONFIGURATION ===
  search do
    strategy :full_text
    fields :name, :email
    suggestions_from :name, :email
    highlight_matches true
  end
  
  # === ACTIONS ===
  actions do
    # Bulk actions
    bulk :activate, label: "Activate Selected" do
      update active: true
      success_message "Users activated successfully"
    end
    
    bulk :deactivate, label: "Deactivate Selected" do
      update active: false
      confirm "Are you sure you want to deactivate these users?"
    end
    
    bulk :export, label: "Export to CSV" do
      format :csv
      fields :name, :email, :role, :created_at
    end
    
    # Row actions
    row :edit, icon: "edit", label: "Edit User"
    row :delete, icon: "trash", label: "Delete", confirm: true do
      condition { |user| current_user != user }
    end
    
    row :impersonate, icon: "user-switch", label: "Login as User" do
      condition { |user| current_user.admin? && user.active? }
      action { |user| impersonate_user(user) }
    end
  end
  
  # === FORMS ===
  forms do
    # Create form
    create do
      field :name, required: true, placeholder: "Enter full name"
      field :email, required: true, placeholder: "user@example.com"
      field :role, as: :select, options: User.roles.keys, default: "user"
      field :active, as: :checkbox, default: true
      
      section "Profile Information" do
        field :bio, as: :textarea, rows: 4
        field :avatar, as: :file, accept: "image/*"
      end
    end
    
    # Edit form (inherits from create, can override)
    edit do
      inherit_from :create
      
      # Add additional fields for editing
      field :last_login_at, as: :datetime, readonly: true
      field :login_count, as: :number, readonly: true
    end
  end
  
  # === PERFORMANCE ===
  performance do
    # Pagination
    paginate_with :cursor, per_page: 25, max_per_page: 100
    
    # Eager loading
    includes :profile, :company
    preload :orders, :reviews
    
    # Caching
    cache_counts_for :orders, :reviews
    cache_page_for 5.minutes
    
    # Indexing hints
    suggest_indexes :name, :email, :active, :created_at
  end
  
  # === PERMISSIONS ===
  permissions do
    # Simple role-based permissions
    allow :read, for: :all
    allow :create, for: :admin, :manager
    allow :update, for: :admin, :manager
    allow :update, for: :user, condition: :own_record?
    allow :delete, for: :admin, condition: :not_self?
    
    # Custom permission methods
    def own_record?(user)
      current_user == user
    end
    
    def not_self?(user)
      current_user != user
    end
  end
  
  # === CUSTOMIZATION ===
  customize do
    # Custom CSS classes
    table_class "users-table"
    row_class { |user| user.active? ? "active-user" : "inactive-user" }
    
    # Custom JavaScript
    stimulus_controller "user-management"
    
    # Custom partial overrides
    partial :show_header, "admin/users/custom_header"
  end
end
```

### 2. **Alternative: YAML-Based Configuration**

```yaml
# app/admin/users.yml
resource:
  title: "User Management"
  model: User
  icon: users
  
display:
  fields:
    - name: id
      type: number
      label: ID
      
    - name: name
      type: text
      required: true
      searchable: true
      sortable: true
      
    - name: email
      type: email
      required: true
      searchable: true
      help_text: "User's primary email address"
      
    - name: role
      type: badge
      options: <%= User.roles.keys %>
      color_map:
        admin: red
        manager: blue
        user: green
        
    - name: active
      type: status_badge
      true_label: Active
      false_label: Inactive
      
    - name: created_at
      type: datetime
      label: Joined
      
    - name: orders_count
      type: counter
      count_of: orders

filters:
  - field: name
    type: text_search
    
  - field: role
    type: select
    options: <%= User.roles.keys %>
    
  - field: active
    type: boolean
    labels:
      true: Active
      false: Inactive

search:
  strategy: full_text
  fields: [name, email]
  suggestions_from: [name, email]

permissions:
  read: all
  create: [admin, manager]
  update: [admin, manager, own_record]
  delete: [admin, not_self]
```

### 3. **Block-Based Builder Pattern**

```ruby
class UserResource < Rama::Resource
  configure do |c|
    c.model User
    c.title "User Management"
    c.icon "users"
  end
  
  display_fields do |fields|
    fields.add :name do |f|
      f.type :text
      f.required true
      f.searchable true
      f.link_to { |user| admin_user_path(user) }
    end
    
    fields.add :email do |f|
      f.type :email
      f.required true
      f.searchable true
      f.help_text "User's primary email address"
    end
    
    fields.add :role do |f|
      f.type :badge
      f.options User.roles.keys
      f.color_map admin: :red, manager: :blue, user: :green
    end
  end
  
  filter_by do |filters|
    filters.text :name, :email
    filters.select :role, options: User.roles.keys
    filters.boolean :active
    filters.date_range :created_at
  end
  
  search_with do |search|
    search.strategy :full_text
    search.fields :name, :email
    search.highlight true
  end
  
  authorize_with do |auth|
    auth.allow :read, for: :all
    auth.allow :create, for: [:admin, :manager]
    auth.allow :update, for: [:admin, :manager]
    auth.allow :update, for: :user, if: :own_record?
    auth.allow :delete, for: :admin, unless: :self?
  end
end
```

### 4. **Fluent Interface Pattern**

```ruby
class UserResource < Rama::Resource
  setup
    .model(User)
    .title("User Management")
    .icon("users")
    .description("Manage system users and permissions")
  
  fields
    .text(:name).required.searchable.sortable
    .email(:email).required.searchable.help("Primary email address")
    .badge(:role).options(User.roles.keys).colors(admin: :red, user: :green)
    .status(:active).labels(true: "Active", false: "Inactive")
    .datetime(:created_at).label("Joined")
    .counter(:orders_count).count_of(:orders)
  
  filters
    .text(:name, :email)
    .select(:role).options(User.roles.keys)
    .boolean(:active)
    .date_range(:created_at)
  
  search
    .strategy(:full_text)
    .fields(:name, :email)
    .highlight_matches
  
  permissions
    .allow(:read).for(:all)
    .allow(:create, :update).for(:admin, :manager)
    .allow(:update).for(:user).if(:own_record?)
    .allow(:delete).for(:admin).unless(:self?)
  
  performance
    .paginate(:cursor, per_page: 25)
    .includes(:profile, :company)
    .cache_counts(:orders, :reviews)
end
```

## Recommended Approach: Grouped Sections with Smart Defaults

The **grouped sections approach** (#1) is recommended because it:

1. **Separates concerns** clearly
2. **Self-documents** the configuration
3. **Provides smart defaults** 
4. **Reduces repetition**
5. **Scales well** for complex resources
6. **Maintains Ruby syntax** (familiar to Rails developers)

### Key Improvements:

1. **Semantic Grouping**: `display`, `filters`, `search`, `actions`, `forms`, `performance`, `permissions`
2. **Smart Field Inference**: Automatically infer searchable, sortable, filterable from field definitions
3. **Declarative Actions**: Clear bulk and row actions with conditions
4. **Readable Permissions**: Simple role-based syntax with custom conditions
5. **Performance Hints**: Explicit performance optimizations
6. **Visual Customization**: CSS classes, Stimulus controllers, partial overrides

This approach makes admin resource definitions much more readable, maintainable, and self-documenting while providing powerful functionality.

## Implementation Status

✅ **Completed:**
- DSL configuration classes (`lib/rama/dsl_configs.rb`)
- Improved Resource class (`lib/rama/improved_resource.rb`)
- Complete examples (`examples/improved_user_resource.rb`)
- Comparison examples (`examples/comparison_examples.rb`)
- Migration guide (`DSL_MIGRATION_GUIDE.md`)
- Updated README with new syntax

## Key Improvements Delivered

### 1. **Semantic Grouping**
- `display` - Field definitions with inline configuration
- `filters` - Filtering options with smart defaults
- `search` - Search configuration and strategies
- `actions` - Bulk and row actions with conditions
- `forms` - Create/edit form definitions
- `performance` - Optimization settings
- `permissions` - Role-based access control
- `customize` - UI customization options

### 2. **Self-Documenting Syntax**
```ruby
# Old: What does this do?
field :orders_count, :has_many_count, association: :orders

# New: Clear and obvious
show :orders_count, as: :counter do
  count_of :orders
  link_to { |user| admin_orders_path(user_id: user.id) }
end
```

### 3. **Reduced Repetition**
```ruby
# Old: Duplicate definitions
field :role, :select, collection: User.roles.keys
filter :role, :select, collection: User.roles.keys

# New: Single definition with smart inference
show :role, as: :badge do
  options User.roles.keys
  color_map(admin: :red, user: :green)
end
# Filter automatically inferred from searchable fields
```

### 4. **Enhanced Readability**
- Block-based configuration for complex options
- Descriptive method names (`count_of`, `color_map`, `true_label`)
- Logical grouping of related functionality
- Clear separation of concerns

### 5. **Backward Compatibility**
- Old DSL syntax still works
- Gradual migration path
- No breaking changes for existing code

## Usage Examples

### Simple Resource
```ruby
class ProductResource < Rama::Resource
  title "Products"
  model Product

  display do
    show :name do
      searchable
      sortable
    end
    show :price, as: :currency
    show :in_stock, as: :boolean
  end

  filters do
    text :name
    boolean :in_stock
  end
end
```

### Complex Resource with All Features
```ruby
class OrderResource < Rama::Resource
  title "Order Management"
  description "Comprehensive order tracking"
  model Order
  icon "shopping-cart"

  display do
    show :id, as: :number, label: "Order #"
    show :customer_name, as: :text do
      searchable
      link_to { |order| admin_customer_path(order.customer) }
    end
    show :status, as: :badge do
      color_map(pending: :yellow, shipped: :green, cancelled: :red)
    end
    show :total, as: :currency
  end

  filters do
    text :customer_name
    select :status, options: Order.statuses.keys
    date_range :created_at
  end

  actions do
    bulk :mark_shipped do
      update status: 'shipped'
      success_message "Orders marked as shipped"
    end

    row :cancel, icon: "x" do
      condition { |order| order.can_be_cancelled? }
      confirm "Cancel this order?"
    end
  end

  permissions do
    allow :read, for: [:admin, :manager, :sales]
    allow :create, :update, for: [:admin, :manager]
    allow :delete, for: :admin
  end
end
```

This improved DSL makes Rama resources much more readable, maintainable, and feature-rich while maintaining full backward compatibility.
