# frozen_string_literal: true

# COMPARISON: Old vs New DSL

# ===== OLD DSL (Current) =====
class OldUserResource < Rama::Resource
  model User

  # Field definitions - repetitive and verbose
  field :name, :string, searchable: true, required: true
  field :email, :email, searchable: true, required: true
  field :role, :select, collection: User.roles.keys
  field :active, :boolean
  field :created_at, :datetime
  field :orders_count, :has_many_count, association: :orders

  # Filters - duplicate field definitions
  filter :role, :select, collection: User.roles.keys
  filter :active, :boolean
  filter :created_at, :date_range

  # Search configuration - separate from fields
  search fields: [:name, :email], strategy: :full_text

  # Performance optimization - mixed with other concerns
  performance do
    pagination :cursor, batch_size: 50
    cache_association_counts :orders, :reviews
    includes :profile, :company
  end

  # Authorization - complex syntax
  authorize do
    can :read, User
    can :create, User, if: -> { current_user.admin? }
    can :update, User, if: -> { current_user.admin? || current_user == resource }
    can :destroy, User, if: -> { current_user.admin? && current_user != resource }
  end
end

# ===== NEW DSL (Improved) =====
class NewUserResource < Rama::Resource
  # === BASIC CONFIGURATION ===
  title 'User Management'
  description 'Manage system users and their permissions'
  model User
  icon 'users'

  # === DISPLAY FIELDS ===
  display do
    show :name, as: :text, required: true do
      searchable # Clear, declarative
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
      true_label 'Active'
      false_label 'Inactive'
    end

    show :orders_count, as: :counter do
      count_of :orders # Self-documenting
    end
  end

  # === FILTERING ===
  filters do
    text :name, :email # Concise
    select :role, options: User.roles.keys
    boolean :active, labels: { true => 'Active', false => 'Inactive' }
    date_range :created_at, label: 'Join Date'
  end

  # === SEARCH CONFIGURATION ===
  search do
    strategy :full_text
    fields :name, :email
    highlight_matches true
  end

  # === ACTIONS ===
  actions do
    bulk :activate, label: 'Activate Selected' do
      update active: true
      success_message 'Users activated successfully'
    end

    row :impersonate, icon: 'user-switch' do
      condition { |user| current_user.admin? && user.active? }
    end
  end

  # === PERMISSIONS ===
  permissions do
    allow :read, for: :all # Simple, readable
    allow :create, for: [:admin, :manager]
    allow :update, for: :user, condition: :own_record?
    allow :delete, for: :admin, condition: :not_self?
  end
end

# ===== SIMPLE RESOURCE EXAMPLE =====
class SimpleProductResource < Rama::Resource
  title 'Products'
  model Product
  icon 'package'

  display do
    show :name do
      searchable
      sortable
    end

    show :price, as: :currency
    show :category, as: :badge
    show :in_stock, as: :boolean
  end

  filters do
    text :name
    select :category, options: Product.categories
    boolean :in_stock
  end

  search do
    fields :name, :description
  end

  permissions do
    allow :read, for: :all
    allow :create, :update, :delete, for: :admin
  end
end

# ===== COMPLEX RESOURCE EXAMPLE =====
class ComplexOrderResource < Rama::Resource
  title 'Order Management'
  description 'Comprehensive order tracking and management'
  model Order
  icon 'shopping-cart'

  display do
    show :id, as: :number, label: 'Order #'

    show :customer_name, as: :text do
      searchable
      link_to { |order| admin_customer_path(order.customer) }
    end

    show :status, as: :badge do
      color_map(
        pending: :yellow,
        processing: :blue,
        shipped: :green,
        delivered: :green,
        cancelled: :red,
      )
    end

    show :total, as: :currency do
      sortable
    end

    show :items_count, as: :counter do
      count_of :order_items
    end

    show :created_at, as: :datetime, label: 'Order Date'
    show :shipped_at, as: :datetime, label: 'Shipped'
  end

  filters do
    text :customer_name
    select :status, options: Order.statuses.keys
    date_range :created_at, label: 'Order Date'
    number_range :total, label: 'Order Total'
  end

  search do
    strategy :full_text
    fields :customer_name, :id
    suggestions_from :customer_name
  end

  actions do
    bulk :mark_shipped, label: 'Mark as Shipped' do
      update status: 'shipped', shipped_at: Time.current
      confirm 'Mark selected orders as shipped?'
    end

    bulk :export_invoices, label: 'Export Invoices' do
      format :pdf
      action { |orders| GenerateInvoicesJob.perform_later(orders.pluck(:id)) }
    end

    row :view_details, icon: 'eye', label: 'View'
    row :print_invoice, icon: 'printer', label: 'Print Invoice'
    row :cancel, icon: 'x', label: 'Cancel Order' do
      condition(&:can_be_cancelled?)
      confirm 'Cancel this order?'
    end
  end

  forms do
    create do
      field :customer_id, as: :select, options: Customer.pluck(:name, :id)
      field :status, as: :select, options: Order.statuses.keys, default: 'pending'

      section 'Order Items' do
        field :order_items, as: :nested_form do
          field :product_id, as: :select, options: Product.pluck(:name, :id)
          field :quantity, as: :number, default: 1
          field :price, as: :currency
        end
      end

      section 'Shipping' do
        field :shipping_address, as: :textarea
        field :shipping_method, as: :select, options: ['standard', 'express', 'overnight']
      end
    end

    edit do
      inherit_from :create
      field :tracking_number, as: :text
      field :shipped_at, as: :datetime
    end
  end

  performance do
    paginate_with :cursor, per_page: 50
    includes :customer, :order_items, :products
    cache_counts_for :order_items
    suggest_indexes :status, :created_at, :customer_id
  end

  permissions do
    allow :read, for: [:admin, :manager, :sales]
    allow :create, :update, for: [:admin, :manager]
    allow :delete, for: :admin
  end

  customize do
    table_class 'orders-table'
    row_class { |order| "order-#{order.status}" }
    stimulus_controller 'order-management'
  end
end
