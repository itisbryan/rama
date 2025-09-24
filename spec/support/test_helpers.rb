# frozen_string_literal: true

module Rama::TestHelpers
  # Authentication helpers
  def sign_in_admin_user(user = nil)
    @current_admin_user = user || create(:admin_user)
    allow_any_instance_of(Rama::ApplicationController) # rubocop:disable RSpec/AnyInstance
      .to receive(:current_admin_user).and_return(@current_admin_user)
    allow_any_instance_of(Rama::ApplicationController) # rubocop:disable RSpec/AnyInstance
      .to receive(:admin_user_signed_in?).and_return(true)
    @current_admin_user
  end

  def sign_out_admin_user
    @current_admin_user = nil
    allow_any_instance_of(Rama::ApplicationController) # rubocop:disable RSpec/AnyInstance
      .to receive(:current_admin_user).and_return(nil)
    allow_any_instance_of(Rama::ApplicationController) # rubocop:disable RSpec/AnyInstance
      .to receive(:admin_user_signed_in?).and_return(false)
  end

  # Resource helpers
  def create_test_resource(name, model_class, &block)
    resource_class = Class.new(Rama::Resource) do
      model model_class
      instance_eval(&block) if block_given?
    end

    Rama.register_resource(name, resource_class)
    resource_class
  end

  # Cache helpers
  def clear_rama_cache
    Rails.cache.delete_matched('rama:*')
  end

  # Performance testing helpers
  def measure_performance
    start_time = Time.current
    memory_before = memory_usage

    result = yield

    {
      result: result,
      duration: Time.current - start_time,
      memory_used: memory_usage - memory_before,
    }
  end

  def memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i.kilobytes
  rescue StandardError
    0
  end

  # Database helpers
  def create_large_dataset(model_class, count: 1000)
    model_class.insert_all(
      Array.new(count) { |i|
        {
          name: "Test Record #{i}",
          email: "test#{i}@example.com",
          created_at: Time.current,
          updated_at: Time.current,
        }
      },
    )
  end

  # Search testing helpers
  def setup_search_indexes
    # Create test search indexes for PostgreSQL
    return unless ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')

    ActiveRecord::Base.connection.execute(
      'CREATE EXTENSION IF NOT EXISTS pg_trgm',
    )
    ActiveRecord::Base.connection.execute(
      'CREATE INDEX IF NOT EXISTS test_users_search_idx ON users USING gin(name gin_trgm_ops, email gin_trgm_ops)',
    )
  end

  # Visual builder helpers
  def simulate_drag_and_drop(from_selector, to_selector)
    page.execute_script(<<~JS)
      var from = document.querySelector('#{from_selector}');
      var to = document.querySelector('#{to_selector}');

      var dragStartEvent = new DragEvent('dragstart', {
        dataTransfer: new DataTransfer()
      });
      dragStartEvent.dataTransfer.setData('field-type', from.dataset.fieldType);

      var dropEvent = new DragEvent('drop', {
        dataTransfer: dragStartEvent.dataTransfer
      });

      from.dispatchEvent(dragStartEvent);
      to.dispatchEvent(dropEvent);
    JS
  end

  # Turbo helpers
  def wait_for_turbo
    expect(page).to have_no_css('.turbo-progress-bar')
  end

  def wait_for_turbo_frame(frame_id)
    expect(page).to have_css("turbo-frame##{frame_id}:not([busy])")
  end

  # ActionCable helpers
  def wait_for_cable_message(channel, timeout: 5)
    received_message = nil

    subscription = ActionCable.server.pubsub.subscribe(channel) { |message|
      received_message = JSON.parse(message)
    }

    Timeout.timeout(timeout) do
      sleep 0.1 until received_message
    end

    ActionCable.server.pubsub.unsubscribe(subscription)
    received_message
  end

  # Job testing helpers
  def perform_enqueued_jobs_immediately
    original_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    ActiveJob::Base.queue_adapter.perform_enqueued_jobs = true

    yield
  ensure
    ActiveJob::Base.queue_adapter = original_adapter
  end

  # Component testing helpers
  def render_component(component_class, **args)
    render_inline(component_class.new(**args))
  end

  def expect_component_to_render(component_class, **args)
    expect { render_component(component_class, **args) }.not_to raise_error
  end

  # API testing helpers
  def json_response
    JSON.parse(response.body)
  end

  def api_headers(user = nil)
    headers = { 'Content-Type' => 'application/json' }
    headers['Authorization'] = "Bearer #{generate_api_token(user)}" if user
    headers
  end

  def generate_api_token(user)
    # Simple token generation for testing
    Base64.encode64("#{user.id}:#{user.email}")
  end

  # Bulk operation helpers
  def create_bulk_test_data(model_class, count: 100)
    records = []
    count.times do |i|
      records << model_class.new(
        name: "Bulk Test #{i}",
        email: "bulk#{i}@example.com",
      )
    end
    model_class.import(records)
  end

  # Cache testing helpers
  def with_caching_enabled
    original_cache_enabled = Rama.config.cache_enabled
    Rama.config.cache_enabled = true

    yield
  ensure
    Rama.config.cache_enabled = original_cache_enabled
  end

  def expect_cache_hit(cache_key)
    expect(Rails.cache.exist?(cache_key)).to be true
  end

  def expect_cache_miss(cache_key)
    expect(Rails.cache.exist?(cache_key)).to be false
  end
end
