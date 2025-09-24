# frozen_string_literal: true

module Rama::Authorization
  extend ActiveSupport::Concern

  included do
    before_action :authorize_admin_access!
  end

  private

  def authorize_admin_access!
    case Rama.config.authorization_method
    when :cancancan
      authorize_with_cancancan!
    when :pundit
      authorize_with_pundit!
    when :custom
      authorize_with_custom!
    else
      # Default to allowing all access in development
      return true if Rails.env.development?

      raise 'No authorization method configured'
    end
  end

  def authorize_with_cancancan!
    raise 'CanCanCan not available but configured as authorization method' unless defined?(CanCan)

    authorize! :access, :admin_panel
  end

  def authorize_with_pundit!
    raise 'Pundit not available but configured as authorization method' unless defined?(Pundit)

    authorize :admin_panel, :access?
  end

  def authorize_with_custom!
    # Override this method in your application controller
    redirect_to main_app.root_path unless can_access_admin?
  end

  def can_access_admin?
    # Override this method in your application controller
    case Rama.config.authorization_method
    when :cancancan
      can? :access, :admin_panel
    when :pundit
      policy(:admin_panel).access?
    else
      true
    end
  end

  def authorize_resource_action!(action, resource_class, resource = nil)
    case Rama.config.authorization_method
    when :cancancan
      authorize_cancancan_resource!(action, resource_class, resource)
    when :pundit
      authorize_pundit_resource!(action, resource_class, resource)
    when :custom
      custom_authorization_check(action, resource_class, resource)
    end
  end

  def authorize_cancancan_resource!(action, resource_class, resource)
    if resource
      authorize! action, resource
    else
      authorize! action, resource_class.model
    end
  end

  def authorize_pundit_resource!(action, resource_class, resource)
    if resource
      authorize resource, "#{action}?"
    else
      authorize resource_class.model, "#{action}?"
    end
  end

  def custom_authorization_check?(_action, _resource_class, _resource)
    # Override this method in your application controller
    true
  end

  # Helper methods for checking permissions
  def can_create?(resource_class)
    case Rama.config.authorization_method
    when :cancancan
      can? :create, resource_class.model
    when :pundit
      policy(resource_class.model).create?
    else
      true
    end
  end

  def can_read?(resource)
    case Rama.config.authorization_method
    when :cancancan
      can? :read, resource
    when :pundit
      policy(resource).show?
    else
      true
    end
  end

  def can_update?(resource)
    case Rama.config.authorization_method
    when :cancancan
      can? :update, resource
    when :pundit
      policy(resource).update?
    else
      true
    end
  end

  def can_destroy?(resource)
    case Rama.config.authorization_method
    when :cancancan
      can? :destroy, resource
    when :pundit
      policy(resource).destroy?
    else
      true
    end
  end
end
