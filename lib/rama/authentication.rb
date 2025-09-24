# frozen_string_literal: true

module Rama::Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_admin_user!
    before_action :set_current_admin_user
  end

  private

  def authenticate_admin_user!
    case Rama.config.authentication_method
    when :devise
      authenticate_devise_user!
    when :basic_auth
      authenticate_basic_auth!
    when :custom
      authenticate_custom_user!
    else
      # Default to no authentication in development
      return true if Rails.env.development?

      raise 'No authentication method configured'
    end
  end

  def authenticate_devise_user!
    raise 'Devise not available but configured as authentication method' unless defined?(Devise)

    authenticate_user!
  end

  def authenticate_basic_auth!
    authenticate_or_request_with_http_basic do |username, password|
      username == Rama.config.basic_auth_username &&
        password == Rama.config.basic_auth_password
    end
  end

  def authenticate_custom_user!
    # Override this method in your application controller
    redirect_to main_app.root_path unless admin_user_signed_in?
  end

  def admin_user_signed_in?
    # Override this method in your application controller
    case Rama.config.authentication_method
    when :devise
      user_signed_in?
    when :basic_auth
      true # Already authenticated by basic auth
    else
      false
    end
  end

  def current_admin_user
    @current_admin_user ||= case Rama.config.authentication_method
                            when :devise
                              current_user
                            when :basic_auth
                              Struct.new(:id, :name, :email).new(1, 'Admin', 'admin@example.com')
                            end
  end

  def set_current_admin_user
    @current_admin_user = current_admin_user
  end
end
