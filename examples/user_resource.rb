# frozen_string_literal: true

# Example of the improved, more readable DSL

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
    
    show :last_login_at, as: :datetime, label: "Last Login"
  end
  
  # === FILTERING ===
  filters do
    text :name, :email
    select :role, options: User.roles.keys
    boolean :active, labels: { true: "Active", false: "Inactive" }
    date_range :created_at, label: "Join Date"
    number_range :orders_count, label: "Number of Orders"
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
    create do
      field :name, required: true, placeholder: "Enter full name"
      field :email, as: :email, required: true, placeholder: "user@example.com"
      field :role, as: :select, options: User.roles.keys, default: "user"
      field :active, as: :checkbox, default: true
      
      section "Profile Information" do
        field :bio, as: :textarea, rows: 4
        field :avatar, as: :file, accept: "image/*"
      end
    end
    
    edit do
      inherit_from :create
      
      # Add additional fields for editing
      field :last_login_at, as: :datetime, readonly: true
      field :login_count, as: :number, readonly: true
    end
  end
  
  # === PERFORMANCE ===
  performance do
    paginate_with :cursor, per_page: 25, max_per_page: 100
    includes :profile, :company
    preload :orders, :reviews
    cache_counts_for :orders, :reviews
    cache_page_for 5.minutes
    suggest_indexes :name, :email, :active, :created_at
  end
  
  # === PERMISSIONS ===
  permissions do
    allow :read, for: :all
    allow :create, for: [:admin, :manager]
    allow :update, for: [:admin, :manager]
    allow :update, for: :user, condition: :own_record?
    allow :delete, for: :admin, condition: :not_self?
    
    # Custom permission methods
    def own_record?(user, current_user)
      current_user == user
    end
    
    def not_self?(user, current_user)
      current_user != user
    end
  end
  
  # === CUSTOMIZATION ===
  customize do
    table_class "users-table"
    row_class { |user| user.active? ? "active-user" : "inactive-user" }
    stimulus_controller "user-management"
    partial :show_header, "admin/users/custom_header"
  end
end
