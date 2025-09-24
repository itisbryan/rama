# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Rama::Resource do
  let(:user_class) { User }
  
  describe 'DSL configuration' do
    it 'allows defining fields with types and options' do
      resource_class = Class.new(described_class) do
        model User
        field :name, :string, searchable: true, required: true
        field :email, :email, searchable: true
        field :active, :boolean
        field :created_at, :datetime
      end

      expect(resource_class.fields.keys).to include(:name, :email, :active, :created_at)
      expect(resource_class.fields[:name][:type]).to eq(:string)
      expect(resource_class.fields[:name][:options][:searchable]).to be true
      expect(resource_class.fields[:name][:options][:required]).to be true
    end

    it 'allows defining filters' do
      resource_class = Class.new(described_class) do
        model User
        filter :active, :boolean
        filter :role, :select, collection: ['admin', 'user']
        filter :created_at, :date_range
      end

      expect(resource_class.filters.keys).to include(:active, :role, :created_at)
      expect(resource_class.filters[:role][:options][:collection]).to eq(['admin', 'user'])
    end

    it 'allows defining search configuration' do
      resource_class = Class.new(described_class) do
        model User
        search fields: [:name, :email], strategy: :full_text
      end

      expect(resource_class.search_config[:fields]).to eq([:name, :email])
      expect(resource_class.search_config[:strategy]).to eq(:full_text)
    end

    it 'allows defining performance optimizations' do
      resource_class = Class.new(described_class) do
        model User
        performance do
          pagination :cursor, batch_size: 50
          cache_association_counts :orders, :reviews
          includes :profile, :company
        end
      end

      expect(resource_class.performance_config[:pagination][:type]).to eq(:cursor)
      expect(resource_class.performance_config[:pagination][:batch_size]).to eq(50)
      expect(resource_class.performance_config[:cache_associations]).to include(:orders, :reviews)
      expect(resource_class.performance_config[:includes]).to include(:profile, :company)
    end
  end

  describe 'query building' do
    let(:resource_class) do
      Class.new(described_class) do
        model User
        field :name, :string, searchable: true
        field :email, :email, searchable: true
        field :active, :boolean
        filter :active, :boolean
        filter :role, :select
      end
    end

    before do
      create_list(:user, 5, active: true, role: 'user')
      create_list(:user, 3, active: false, role: 'admin')
    end

    it 'builds basic scope' do
      scope = resource_class.build_scope({})
      expect(scope.count).to eq(8)
    end

    it 'applies filters correctly' do
      scope = resource_class.build_scope({ active: true })
      expect(scope.count).to eq(5)
      expect(scope.all?(&:active)).to be true
    end

    it 'applies multiple filters' do
      scope = resource_class.build_scope({ active: false, role: 'admin' })
      expect(scope.count).to eq(3)
      expect(scope.all? { |u| !u.active && u.role == 'admin' }).to be true
    end

    it 'applies search' do
      user = create(:user, name: 'John Doe', email: 'john@example.com')
      scope = resource_class.build_scope({ search: 'John' })
      expect(scope).to include(user)
    end
  end

  describe 'performance optimizations' do
    let(:resource_class) do
      Class.new(described_class) do
        model User
        performance do
          includes :orders, :profile
          cache_association_counts :orders
        end
      end
    end

    it 'applies includes to prevent N+1 queries' do
      create_list(:user, 3, :with_orders, :with_profile)
      
      expect do
        scope = resource_class.build_scope({})
        scope.each do |user|
          user.orders.count
          user.profile&.bio
        end
      end.to make_database_queries(count: be <= 5) # Should be much fewer than N+1
    end

    it 'caches association counts' do
      users = create_list(:user, 3, :with_orders)
      
      with_caching_enabled do
        # First call should hit database
        expect do
          users.each { |user| resource_class.cached_association_count(user, :orders) }
        end.to make_database_queries(count: be > 0)
        
        # Second call should use cache
        expect do
          users.each { |user| resource_class.cached_association_count(user, :orders) }
        end.to make_database_queries(count: 0)
      end
    end
  end

  describe 'field type handling' do
    let(:resource_class) do
      Class.new(described_class) do
        model User
        field :name, :string
        field :email, :email
        field :active, :boolean
        field :orders_count, :has_many_count, association: :orders
      end
    end

    let(:user) { create(:user, :with_orders) }

    it 'formats field values correctly' do
      expect(resource_class.format_field_value(user, :name)).to eq(user.name)
      expect(resource_class.format_field_value(user, :email)).to eq(user.email)
      expect(resource_class.format_field_value(user, :active)).to eq(user.active)
    end

    it 'handles association counts' do
      count = resource_class.format_field_value(user, :orders_count)
      expect(count).to eq(user.orders.count)
    end
  end

  describe 'authorization integration' do
    let(:admin_user) { create(:admin_user) }
    let(:regular_user) { create(:user) }
    
    let(:resource_class) do
      Class.new(described_class) do
        model User
        
        authorize do
          can :read, User
          can :create, User, if: -> { current_user.admin? }
          can :update, User, if: -> { current_user.admin? || current_user == resource }
          can :destroy, User, if: -> { current_user.admin? && current_user != resource }
        end
      end
    end

    it 'allows reading for all users' do
      expect(resource_class.can?(:read, regular_user, admin_user)).to be true
      expect(resource_class.can?(:read, regular_user, regular_user)).to be true
    end

    it 'restricts creation to admins' do
      expect(resource_class.can?(:create, nil, admin_user)).to be true
      expect(resource_class.can?(:create, nil, regular_user)).to be false
    end

    it 'allows users to update themselves' do
      expect(resource_class.can?(:update, regular_user, regular_user)).to be true
      expect(resource_class.can?(:update, admin_user, regular_user)).to be false
    end
  end
end
