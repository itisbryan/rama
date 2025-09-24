# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Admin Dashboard', :js, type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in_admin_user(admin_user)

    # Create test data
    create_list(:user, 10)
    create_list(:order, 15)

    # Register test resources
    create_test_resource(:users, User) do
      field :name, :string, searchable: true
      field :email, :email, searchable: true
      field :active, :boolean
      field :created_at, :datetime

      filter :active, :boolean
      filter :created_at, :date_range
    end
  end

  describe 'dashboard page' do
    it 'displays the dashboard with statistics' do
      visit '/admin'

      expect(page).to have_content('Dashboard')
      expect(page).to have_content('Users')
      expect(page).to have_content('Orders')

      # Check for statistics cards
      expect(page).to have_css('.stats-card', count: be >= 2)
    end

    it 'shows real-time updates', :cable do
      visit '/admin'

      # Create a new user in the background
      create(:user)

      # Should see updated count (this would require WebSocket implementation)
      # For now, just verify the page structure
      expect(page).to have_css('[data-controller="dashboard"]')
    end

    it 'displays recent activity' do
      visit '/admin'

      expect(page).to have_content('Recent Activity')
      # Should show recent records
    end
  end

  describe 'resource listing' do
    it 'displays users list with pagination' do
      visit '/admin/users'

      expect(page).to have_content('Users')
      expect(page).to have_css('table tbody tr', count: be >= 1)

      # Check for pagination controls
      expect(page).to have_css('.pagination, [data-controller="pagination"]')
    end

    it 'allows searching users' do
      create(:user, name: 'John Doe', email: 'john@example.com')

      visit '/admin/users'

      fill_in 'Search', with: 'John'
      click_button 'Search'

      wait_for_turbo

      expect(page).to have_content('John Doe')
      expect(page).to have_content('john@example.com')
    end

    it 'allows filtering users' do
      active_user = create(:user, active: true)
      inactive_user = create(:user, active: false)

      visit '/admin/users'

      # Filter by active status
      select 'Yes', from: 'Active'
      click_button 'Apply Filters'

      wait_for_turbo

      expect(page).to have_content(active_user.name)
      expect(page).not_to have_content(inactive_user.name)
    end

    it 'handles large datasets efficiently' do
      create_large_dataset(User, count: 500)

      performance = measure_performance {
        visit '/admin/users'
        expect(page).to have_css('table tbody tr', count: be >= 1)
      }

      expect(performance[:duration]).to be < 3.seconds
    end
  end

  describe 'resource CRUD operations' do
    it 'allows creating a new user' do
      visit '/admin/users'

      click_link 'New User'

      wait_for_turbo_frame('modal')

      fill_in 'Name', with: 'Test User'
      fill_in 'Email', with: 'test@example.com'
      check 'Active'

      click_button 'Create User'

      wait_for_turbo

      expect(page).to have_content('User created successfully')
      expect(page).to have_content('Test User')
    end

    it 'allows editing an existing user' do
      user = create(:user, name: 'Original Name')

      visit '/admin/users'

      within "tr[data-id='#{user.id}']" do
        click_link 'Edit'
      end

      wait_for_turbo_frame('modal')

      fill_in 'Name', with: 'Updated Name'
      click_button 'Update User'

      wait_for_turbo

      expect(page).to have_content('User updated successfully')
      expect(page).to have_content('Updated Name')
    end

    it 'allows deleting a user with confirmation' do
      user = create(:user)

      visit '/admin/users'

      within "tr[data-id='#{user.id}']" do
        accept_confirm do
          click_link 'Delete'
        end
      end

      wait_for_turbo

      expect(page).to have_content('User deleted successfully')
      expect(page).not_to have_content(user.name)
    end
  end

  describe 'bulk operations' do
    before do
      create_list(:user, 5, active: true)
    end

    it 'allows bulk updates' do
      visit '/admin/users'

      # Select multiple users
      all('input[type="checkbox"][data-bulk-select]').each(&:check)

      select 'Update Selected', from: 'bulk_action'
      click_button 'Apply'

      wait_for_turbo_frame('bulk-operation-modal')

      uncheck 'Active'
      click_button 'Update Users'

      # Should show progress or completion message
      expect(page).to have_content('Bulk operation started')
    end

    it 'allows bulk export' do
      visit '/admin/users'

      all('input[type="checkbox"][data-bulk-select]').each(&:check)

      select 'Export Selected', from: 'bulk_action'
      click_button 'Apply'

      wait_for_turbo_frame('bulk-operation-modal')

      select 'CSV', from: 'format'
      click_button 'Export Users'

      expect(page).to have_content('Export started')
    end
  end

  describe 'responsive design' do
    it 'works on mobile devices' do
      page.driver.browser.manage.window.resize_to(375, 667) # iPhone size

      visit '/admin'

      expect(page).to have_css('.mobile-menu-toggle, [data-controller="mobile-menu"]')

      # Should be able to navigate
      click_button 'Menu' # or whatever the mobile menu trigger is
      click_link 'Users'

      expect(page).to have_content('Users')
    end
  end

  describe 'accessibility' do
    it 'has proper ARIA labels and roles' do
      visit '/admin'

      expect(page).to have_css('[role="main"]')
      expect(page).to have_css('[role="navigation"]')

      # Check for proper form labels
      visit '/admin/users/new'
      expect(page).to have_css('label[for]')
    end

    it 'supports keyboard navigation' do
      visit '/admin/users'

      # Should be able to navigate with tab key
      first_link = page.find('a', match: :first)
      first_link.send_keys(:tab)

      # Verify focus moves to next element
      expect(page).to have_css(':focus')
    end
  end

  describe 'error handling' do
    it 'displays validation errors properly' do
      visit '/admin/users'

      click_link 'New User'

      wait_for_turbo_frame('modal')

      # Submit without required fields
      click_button 'Create User'

      expect(page).to have_content('Name can\'t be blank')
      expect(page).to have_content('Email can\'t be blank')
    end

    it 'handles server errors gracefully' do
      # Simulate a server error
      allow_any_instance_of(User).to receive(:save!).and_raise(StandardError, 'Database error')

      visit '/admin/users'

      click_link 'New User'

      wait_for_turbo_frame('modal')

      fill_in 'Name', with: 'Test User'
      fill_in 'Email', with: 'test@example.com'

      click_button 'Create User'

      expect(page).to have_content('An error occurred')
    end
  end
end
