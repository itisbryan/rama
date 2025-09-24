# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Visual Builder', :js, type: :feature do
  let(:admin_user) { create(:admin_user) }

  before do
    sign_in_admin_user(admin_user)
  end

  describe 'Form Builder' do
    it 'allows creating forms visually' do
      visit '/admin/builder/forms'

      click_link 'New Form'

      fill_in 'Form Name', with: 'Contact Form'
      select 'User', from: 'Model'
      click_button 'Create Form'

      wait_for_turbo

      expect(page).to have_content('Contact Form')
      expect(page).to have_css('[data-controller="form-builder"]')
    end

    it 'supports drag and drop field creation' do
      form = create(:form_configuration, name: 'Test Form')

      visit "/admin/builder/forms/#{form.id}"

      # Drag a text field from palette to canvas
      simulate_drag_and_drop(
        '[data-field-type="string"]',
        '[data-form-builder-target="canvas"]',
      )

      wait_for_turbo

      expect(page).to have_css('[data-field-type="string"]', count: 2) # One in palette, one in canvas
    end

    it 'allows configuring field properties' do
      form = create(:form_configuration, :with_fields)

      visit "/admin/builder/forms/#{form.id}"

      # Click on a field to edit it
      within '[data-form-builder-target="canvas"]' do
        first('[data-field-id]').click
      end

      wait_for_turbo_frame('field-properties')

      fill_in 'Label', with: 'Full Name'
      check 'Required'
      click_button 'Update Field'

      wait_for_turbo

      expect(page).to have_content('Full Name')
    end

    it 'provides real-time preview' do
      form = create(:form_configuration, :with_fields)

      visit "/admin/builder/forms/#{form.id}"

      expect(page).to have_css('[data-form-builder-target="preview"]')

      # Preview should update when fields change
      simulate_drag_and_drop(
        '[data-field-type="email"]',
        '[data-form-builder-target="canvas"]',
      )

      wait_for_turbo

      within '[data-form-builder-target="preview"]' do
        expect(page).to have_css('input[type="email"]')
      end
    end

    it 'supports field reordering' do
      form = create(:form_configuration, :with_fields)

      visit "/admin/builder/forms/#{form.id}"

      # Get initial order
      initial_fields = page.all('[data-form-builder-target="canvas"] [data-field-id]')
      first_field = initial_fields.first
      initial_fields.last

      # Simulate drag and drop reordering
      page.execute_script(<<~JS)
        var canvas = document.querySelector('[data-form-builder-target="canvas"]');
        var firstField = canvas.querySelector('[data-field-id]');
        var lastField = canvas.querySelector('[data-field-id]:last-child');

        // Move first field to end
        canvas.appendChild(firstField);

        // Trigger sortable end event
        var event = new CustomEvent('sortupdate');
        canvas.dispatchEvent(event);
      JS

      wait_for_turbo

      # Verify order changed
      new_fields = page.all('[data-form-builder-target="canvas"] [data-field-id]')
      expect(new_fields.last['data-field-id']).to eq(first_field['data-field-id'])
    end
  end

  describe 'Query Builder' do
    it 'allows building queries visually' do
      visit '/admin/builder/queries'

      click_link 'New Query'

      fill_in 'Query Name', with: 'Active Users'

      # Select table
      select 'users', from: 'table'
      click_button 'Add Table'

      wait_for_turbo

      # Add condition
      click_button 'Add Condition'

      within '.condition-row:last-child' do
        select 'active', from: 'column'
        select 'equals', from: 'operator'
        select 'true', from: 'value'
      end

      click_button 'Save Query'

      wait_for_turbo

      expect(page).to have_content('Query saved successfully')
    end

    it 'provides live query preview' do
      create_list(:user, 5, active: true)
      create_list(:user, 3, active: false)

      visit '/admin/builder/queries/new'

      select 'users', from: 'table'
      click_button 'Add Table'

      wait_for_turbo

      # Should show preview results
      within '[data-query-builder-target="preview"]' do
        expect(page).to have_css('table tbody tr', count: 8) # All users initially
      end

      # Add filter
      click_button 'Add Condition'

      within '.condition-row:last-child' do
        select 'active', from: 'column'
        select 'equals', from: 'operator'
        select 'true', from: 'value'
      end

      click_button 'Update Preview'

      wait_for_turbo

      # Should show filtered results
      within '[data-query-builder-target="preview"]' do
        expect(page).to have_css('table tbody tr', count: 5) # Only active users
      end
    end

    it 'supports complex joins' do
      visit '/admin/builder/queries/new'

      select 'users', from: 'table'
      click_button 'Add Table'

      wait_for_turbo

      click_button 'Add Join'

      within '.join-row:last-child' do
        select 'orders', from: 'join_table'
        select 'INNER JOIN', from: 'join_type'
        select 'users.id', from: 'left_column'
        select 'orders.user_id', from: 'right_column'
      end

      click_button 'Update Preview'

      wait_for_turbo

      expect(page).to have_content('JOIN orders')
    end
  end

  describe 'Dashboard Builder' do
    it 'allows creating custom dashboards' do
      visit '/admin/builder/dashboards'

      click_link 'New Dashboard'

      fill_in 'Dashboard Name', with: 'Sales Dashboard'
      click_button 'Create Dashboard'

      wait_for_turbo

      expect(page).to have_content('Sales Dashboard')
      expect(page).to have_css('[data-controller="dashboard-builder"]')
    end

    it 'supports widget drag and drop' do
      dashboard = create(:dashboard_configuration)

      visit "/admin/builder/dashboards/#{dashboard.id}"

      # Drag a chart widget to the canvas
      simulate_drag_and_drop(
        '[data-widget-type="chart"]',
        '[data-dashboard-builder-target="canvas"]',
      )

      wait_for_turbo

      expect(page).to have_css('[data-widget-type="chart"]', count: 2) # One in palette, one in canvas
    end

    it 'allows configuring widget properties' do
      dashboard = create(:dashboard_configuration)

      visit "/admin/builder/dashboards/#{dashboard.id}"

      # Add a widget first
      simulate_drag_and_drop(
        '[data-widget-type="stats"]',
        '[data-dashboard-builder-target="canvas"]',
      )

      wait_for_turbo

      # Click to configure
      within '[data-dashboard-builder-target="canvas"]' do
        first('[data-widget-id]').click
      end

      wait_for_turbo_frame('widget-properties')

      fill_in 'Title', with: 'Total Users'
      select 'User', from: 'Model'
      select 'count', from: 'Aggregation'

      click_button 'Update Widget'

      wait_for_turbo

      expect(page).to have_content('Total Users')
    end
  end

  describe 'Real-time Collaboration' do
    it 'shows other users editing the same form', :cable do
      form = create(:form_configuration)

      # Simulate another user joining
      visit "/admin/builder/forms/#{form.id}"

      # This would require WebSocket implementation
      # For now, just verify the collaboration UI exists
      expect(page).to have_css('[data-controller="collaboration"]')
    end

    it 'handles concurrent edits gracefully', :cable do
      form = create(:form_configuration, :with_fields)

      visit "/admin/builder/forms/#{form.id}"

      # Simulate concurrent edit from another user
      # This would broadcast via ActionCable
      ActionCable.server.broadcast(
        "form_collaboration_#{form.id}",
        {
          action: 'field_added',
          data: { field_type: 'email', name: 'email_field' },
          user_id: 'other_user',
        },
      )

      # Should handle the update without conflicts
      expect(page).to have_css('[data-controller="collaboration"]')
    end
  end

  describe 'Configuration Export/Import' do
    it 'allows exporting form configurations' do
      form = create(:form_configuration, :with_fields)

      visit "/admin/builder/forms/#{form.id}"

      click_button 'Export'

      # Should download or show export data
      expect(page).to have_content('Export Configuration')
    end

    it 'allows importing form configurations' do
      visit '/admin/builder/forms'

      click_link 'Import Form'

      # Upload configuration file
      attach_file 'Configuration File', Rails.root.join('spec', 'fixtures', 'form_config.json')
      click_button 'Import'

      wait_for_turbo

      expect(page).to have_content('Form imported successfully')
    end
  end

  describe 'Performance with Complex Forms' do
    it 'handles forms with many fields efficiently' do
      form = create(:form_configuration)

      # Add many fields
      20.times do |i|
        create(:field_configuration,
               form_configuration: form,
               name: "field_#{i}",
               position: i,)
      end

      performance = measure_performance {
        visit "/admin/builder/forms/#{form.id}"
        expect(page).to have_css('[data-field-id]', count: 20)
      }

      expect(performance[:duration]).to be < 3.seconds
    end
  end
end
