# frozen_string_literal: true

FactoryBot.define do
  factory :user do
    sequence(:name) { |n| "User #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    active { true }
    role { 'user' }
    created_at { Time.current }
    updated_at { Time.current }

    trait :admin do
      role { 'admin' }
    end

    trait :inactive do
      active { false }
    end

    trait :with_orders do
      after(:create) do |user|
        create_list(:order, 3, user: user)
      end
    end

    trait :with_profile do
      after(:create) do |user|
        create(:profile, user: user)
      end
    end
  end

  factory :admin_user, parent: :user, traits: [:admin]

  factory :order do
    association :user
    sequence(:total) { |n| (n * 10.5).round(2) }
    status { 'pending' }
    created_at { Time.current }
    updated_at { Time.current }

    trait :completed do
      status { 'completed' }
    end

    trait :cancelled do
      status { 'cancelled' }
    end
  end

  factory :profile do
    association :user
    bio { "This is a test bio" }
    website { "https://example.com" }
    created_at { Time.current }
    updated_at { Time.current }
  end

  factory :company do
    sequence(:name) { |n| "Company #{n}" }
    sequence(:email) { |n| "company#{n}@example.com" }
    industry { 'Technology' }
    created_at { Time.current }
    updated_at { Time.current }

    trait :with_users do
      after(:create) do |company|
        create_list(:user, 5, company: company)
      end
    end
  end

  # Rama specific factories
  factory :form_configuration, class: 'Rama::FormConfiguration' do
    sequence(:name) { |n| "Test Form #{n}" }
    model_name { 'User' }
    active { true }
    layout_config { { type: 'single_column', spacing: 'normal' } }

    trait :with_fields do
      after(:create) do |form|
        create(:field_configuration, form_configuration: form, name: 'name', field_type: 'string', position: 0)
        create(:field_configuration, form_configuration: form, name: 'email', field_type: 'email', position: 1)
        create(:field_configuration, form_configuration: form, name: 'active', field_type: 'boolean', position: 2)
      end
    end
  end

  factory :field_configuration, class: 'Rama::FieldConfiguration' do
    association :form_configuration
    sequence(:name) { |n| "field_#{n}" }
    field_type { 'string' }
    position { 0 }
    options { {} }
    validation_rules { {} }
    conditional_logic { {} }
  end

  factory :query_configuration, class: 'Rama::QueryConfiguration' do
    sequence(:name) { |n| "Test Query #{n}" }
    model_name { 'User' }
    query_config { { tables: ['users'], conditions: [] } }
    active { true }
  end

  factory :dashboard_configuration, class: 'Rama::DashboardConfiguration' do
    sequence(:name) { |n| "Test Dashboard #{n}" }
    layout_config { { columns: 12, rows: 8 } }
    widgets_config { [] }
    active { true }
  end
end
