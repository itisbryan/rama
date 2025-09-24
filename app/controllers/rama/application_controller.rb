# frozen_string_literal: true

class Rama::ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  before_action :authenticate_admin_user!
  before_action :authorize_admin_access!
  before_action :set_current_admin_user

  layout 'flex_admin/application'

  # Performance monitoring
  around_action :monitor_performance, if: -> { Rama.config.performance_monitoring_enabled }

  # Cache management
  before_action :set_cache_headers

  private

  def authenticate_admin_user!
    case Rama.config.authentication_method
    when :devise
      authenticate_user!
    when :custom
      # Custom authentication logic
      redirect_to main_app.root_path unless admin_user_signed_in?
    end
  end

  def authorize_admin_access!
    case Rama.config.authorization_method
    when :cancancan
      authorize! :access, :admin_panel
    when :custom
      # Custom authorization logic
      redirect_to main_app.root_path unless can_access_admin?
    end
  end

  def set_current_admin_user
    @current_admin_user = current_user
  end

  def admin_user_signed_in?
    # Override in your application
    true
  end

  def can_access_admin?
    # Override in your application
    true
  end

  def monitor_performance
    start_time = Time.current
    memory_before = memory_usage

    yield

    duration = Time.current - start_time
    memory_after = memory_usage
    memory_diff = memory_after - memory_before

    return unless duration > 1.second || memory_diff > 50.megabytes

    Rails.logger.warn(
      "Rama Performance Warning: #{controller_name}##{action_name} " \
      "took #{duration.round(3)}s and used #{memory_diff / 1.megabyte}MB",
    )
  end

  def memory_usage
    `ps -o rss= -p #{Process.pid}`.to_i.kilobytes
  rescue StandardError
    0
  end

  def set_cache_headers
    if Rama.config.cache_enabled
      expires_in 5.minutes, public: false
    else
      expires_now
    end
  end

  # Turbo Stream helpers
  def turbo_stream_flash(type, message)
    turbo_stream.update 'flash', partial: 'flex_admin/shared/flash',
                                 locals: { type: type, message: message }
  end

  def turbo_stream_redirect(url)
    turbo_stream.action :redirect, url
  end

  # Error handling
  rescue_from StandardError, with: :handle_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_not_found
  rescue_from CanCan::AccessDenied, with: :handle_access_denied

  def handle_error(exception)
    Rails.logger.error "Rama Error: #{exception.message}"
    Rails.logger.error exception.backtrace.join("\n")

    respond_to do |format|
      format.html { redirect_to flex_admin.root_path, alert: I18n.t('rama.errors.generic') }
      format.turbo_stream { render turbo_stream: turbo_stream_flash(:error, 'An error occurred') }
      format.json { render json: { error: 'An error occurred' }, status: :internal_server_error }
    end
  end

  def handle_not_found(_exception)
    respond_to do |format|
      format.html { redirect_to flex_admin.root_path, alert: I18n.t('rama.errors.not_found') }
      format.turbo_stream { render turbo_stream: turbo_stream_flash(:error, 'Record not found') }
      format.json { render json: { error: 'Record not found' }, status: :not_found }
    end
  end

  def handle_access_denied(_exception)
    respond_to do |format|
      format.html { redirect_to flex_admin.root_path, alert: I18n.t('rama.errors.access_denied') }
      format.turbo_stream { render turbo_stream: turbo_stream_flash(:error, 'Access denied') }
      format.json { render json: { error: 'Access denied' }, status: :forbidden }
    end
  end
end
