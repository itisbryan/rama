# Rama DSL Migration Guide

This guide helps you migrate from the old DSL syntax to the new, more readable and organized DSL.

## Why Migrate?

The new DSL provides:
- ✅ **Better Organization**: Grouped sections (display, filters, search, etc.)
- ✅ **Self-Documenting**: Clear, semantic method names
- ✅ **Less Repetition**: Smart defaults and inheritance
- ✅ **Enhanced Readability**: Block-based configuration
- ✅ **More Features**: Actions, forms, customization options

## Migration Steps

### 1. Update Base Class

**Old:**
```ruby
class UserResource < Rama::Resource
```

**New:**
```ruby
class UserResource < Rama::Resource
# or keep Rama::Resource (backward compatible)
```

### 2. Add Basic Configuration

**Old:**
```ruby
class UserResource < Rama::Resource
  model User
  # fields and other config...
end
```

**New:**
```ruby
class UserResource < Rama::Resource
  # === BASIC CONFIGURATION ===
  title "User Management"
  description "Manage system users and their permissions"
  model User
  icon "users"
  
  # rest of configuration...
end
```

### 3. Migrate Field Definitions

**Old:**
```ruby
field :name, :string, searchable: true, required: true
field :email, :email, searchable: true, required: true
field :role, :select, collection: User.roles.keys
field :active, :boolean
field :orders_count, :has_many_count, association: :orders
```

**New:**
```ruby
display do
  show :name, as: :text, required: true do
    searchable
    sortable
  end
  
  show :email, as: :email, required: true do
    searchable
    help_text "User's primary email address"
  end
  
  show :role, as: :badge do
    options User.roles.keys
    color_map(admin: :red, user: :green)
  end
  
  show :active, as: :status_badge do
    true_label "Active"
    false_label "Inactive"
  end
  
  show :orders_count, as: :counter do
    count_of :orders
  end
end
```

### 4. Migrate Filters

**Old:**
```ruby
filter :role, :select, collection: User.roles.keys
filter :active, :boolean
filter :created_at, :date_range
```

**New:**
```ruby
filters do
  text :name, :email
  select :role, options: User.roles.keys
  boolean :active, labels: { true: "Active", false: "Inactive" }
  date_range :created_at, label: "Join Date"
end
```

### 5. Migrate Search Configuration

**Old:**
```ruby
search fields: [:name, :email], strategy: :full_text
```

**New:**
```ruby
search do
  strategy :full_text
  fields :name, :email
  highlight_matches true
end
```

### 6. Migrate Performance Configuration

**Old:**
```ruby
performance do
  pagination :cursor, batch_size: 50
  cache_association_counts :orders, :reviews
  includes :profile, :company
end
```

**New:**
```ruby
performance do
  paginate_with :cursor, per_page: 50
  includes :profile, :company
  cache_counts_for :orders, :reviews
  suggest_indexes :name, :email, :active
end
```

### 7. Migrate Authorization

**Old:**
```ruby
authorize do
  can :read, User
  can :create, User, if: -> { current_user.admin? }
  can :update, User, if: -> { current_user.admin? || current_user == resource }
  can :destroy, User, if: -> { current_user.admin? && current_user != resource }
end
```

**New:**
```ruby
permissions do
  allow :read, for: :all
  allow :create, for: [:admin, :manager]
  allow :update, for: :user, condition: :own_record?
  allow :delete, for: :admin, condition: :not_self?
  
  def own_record?(user, current_user)
    current_user == user
  end
  
  def not_self?(user, current_user)
    current_user != user
  end
end
```

## Complete Migration Example

### Before (Old DSL)

```ruby
class UserResource < Rama::Resource
  model User
  
  field :name, :string, searchable: true, required: true
  field :email, :email, searchable: true, required: true
  field :role, :select, collection: User.roles.keys
  field :active, :boolean
  field :created_at, :datetime
  field :orders_count, :has_many_count, association: :orders
  
  filter :role, :select, collection: User.roles.keys
  filter :active, :boolean
  filter :created_at, :date_range
  
  search fields: [:name, :email], strategy: :full_text
  
  performance do
    pagination :cursor, batch_size: 50
    cache_association_counts :orders, :reviews
    includes :profile, :company
  end
  
  authorize do
    can :read, User
    can :create, User, if: -> { current_user.admin? }
    can :update, User, if: -> { current_user.admin? || current_user == resource }
    can :destroy, User, if: -> { current_user.admin? && current_user != resource }
  end
end
```

### After (New DSL)

```ruby
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
    
    show :created_at, as: :datetime, label: "Joined"
    
    show :orders_count, as: :counter do
      count_of :orders
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
    
    row :edit, icon: "edit", label: "Edit User"
    row :delete, icon: "trash", label: "Delete", confirm: true
  end
  
  # === PERFORMANCE ===
  performance do
    paginate_with :cursor, per_page: 50
    includes :profile, :company
    cache_counts_for :orders, :reviews
    suggest_indexes :name, :email, :active, :created_at
  end
  
  # === PERMISSIONS ===
  permissions do
    allow :read, for: :all
    allow :create, for: [:admin, :manager]
    allow :update, for: [:admin, :manager]
    allow :update, for: :user, condition: :own_record?
    allow :delete, for: :admin, condition: :not_self?
    
    def own_record?(user, current_user)
      current_user == user
    end
    
    def not_self?(user, current_user)
      current_user != user
    end
  end
end
```

## Backward Compatibility

The old DSL syntax is still supported for backward compatibility:

```ruby
class UserResource < Rama::Resource
  model User
  field :name, :string, searchable: true  # Still works
  filter :name, :string                   # Still works
  # ... etc
end
```

## Migration Checklist

- [ ] Update basic configuration (title, description, icon)
- [ ] Migrate field definitions to `display` block
- [ ] Migrate filters to `filters` block
- [ ] Migrate search configuration to `search` block
- [ ] Add actions configuration
- [ ] Migrate performance settings
- [ ] Migrate authorization to permissions
- [ ] Add customization options
- [ ] Test all functionality
- [ ] Update tests

## Benefits After Migration

1. **Improved Readability**: Code is self-documenting and easier to understand
2. **Better Organization**: Related configurations are grouped together
3. **Enhanced Features**: Access to new features like actions, forms, customization
4. **Reduced Duplication**: Smart defaults reduce repetitive code
5. **Better Maintainability**: Easier to modify and extend resources

## Need Help?

- Check the [examples](examples/) directory for more migration examples
- Review the [DSL documentation](DSL_DOCUMENTATION.md) for complete syntax reference
- Run tests to ensure everything works after migration
- Use the backward compatibility mode during transition
