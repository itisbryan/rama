# frozen_string_literal: true

require_relative 'dsl_configs'

class Rama::Resource
  include ActiveSupport::Configurable

  class_attribute :model_class_name, :resource_config

  self.resource_config = {
    title: nil,
    description: nil,
    icon: nil,
    fields: {},
    filters: {},
    search: {},
    actions: { bulk: {}, row: {} },
    forms: { create: {}, edit: {} },
    performance: {},
    permissions: {},
    customization: {},
  }

  class << self
    # === BASIC CONFIGURATION ===
    def title(title_text)
      self.resource_config = resource_config.merge(title: title_text)
    end

    def description(desc_text)
      self.resource_config = resource_config.merge(description: desc_text)
    end

    def icon(icon_name)
      self.resource_config = resource_config.merge(icon: icon_name)
    end

    def model(model_class = nil)
      if model_class
        self.model_class_name = model_class.name
      else
        model_class_name&.constantize
      end
    end

    # === FIELD CONFIGURATION ===
    def display(&)
      config = FieldsConfig.new
      config.instance_eval(&) if block_given?
      self.resource_config = resource_config.merge(fields: config.to_h)
    end

    def filters(&)
      config = FiltersConfig.new
      config.instance_eval(&) if block_given?
      self.resource_config = resource_config.merge(filters: config.to_h)
    end

    def search(&)
      config = SearchConfig.new
      config.instance_eval(&) if block_given?
      self.resource_config = resource_config.merge(search: config.to_h)
    end

    def actions(&)
      config = ActionsConfig.new
      config.instance_eval(&) if block_given?
      self.resource_config = resource_config.merge(actions: config.to_h)
    end

    def forms(&)
      config = FormsConfig.new
      config.instance_eval(&) if block_given?
      self.resource_config = resource_config.merge(forms: config.to_h)
    end

    def performance(&)
      config = PerformanceConfig.new
      config.instance_eval(&) if block_given?
      self.resource_config = resource_config.merge(performance: config.to_h)
    end

    def permissions(&)
      config = PermissionsConfig.new
      config.instance_eval(&) if block_given?
      self.resource_config = resource_config.merge(permissions: config.to_h)
    end

    def customization(&)
      config = CustomizationConfig.new
      config.instance_eval(&) if block_given?
      self.resource_config = resource_config.merge(customization: config.to_h)
    end

    # === HELPER METHODS ===
    def inherited(subclass)
      super
      # Auto-register the resource
      resource_name = subclass.name.demodulize.gsub(/Resource$/, '').underscore
      Rama.register_resource(resource_name, subclass)
    end

    # === INSTANCE METHOD ACCESSORS ===
    def resource_title
      resource_config[:title] || default_resource_title
    end

    def resource_description
      resource_config[:description]
    end

    def resource_icon
      resource_config[:icon] || 'table'
    end

    def resource_fields
      resource_config[:fields] || {}
    end

    def resource_filters
      resource_config[:filters] || {}
    end

    def resource_search_config
      resource_config[:search] || {}
    end

    def resource_actions
      resource_config[:actions] || { bulk: {}, row: {} }
    end

    def resource_forms
      resource_config[:forms] || { create: {}, edit: {} }
    end

    def resource_performance_config
      resource_config[:performance] || {}
    end

    def resource_permissions
      resource_config[:permissions] || {}
    end

    def resource_customization
      resource_config[:customization] || {}
    end

    # === QUERY BUILDING ===
    def build_scope(params = {})
      scope = model.all

      # Apply filters
      resource_filters.each do |field_name, filter_config|
        value = params[field_name.to_sym] || params[field_name]
        next if value.blank?

        scope = apply_filter(scope, field_name, filter_config, value)
      end

      # Apply search
      if params[:search].present?
        search_config_data = resource_search_config
        if search_config_data[:fields].present?
          search_engine = Rama::SearchEngine.new(
            model,
            params[:search],
            strategy: search_config_data[:strategy] || :auto,
          )
          scope = search_engine.search
        end
      end

      # Apply performance optimizations
      performance_config_data = resource_performance_config
      scope = scope.includes(*performance_config_data[:includes]) if performance_config_data[:includes].present?

      scope
    end

    def apply_filter(scope, field_name, filter_config, value)
      case filter_config[:type]
      when :string
        scope.where("#{field_name} ILIKE ?", "%#{value}%")
      when :exact, :select, nil
        scope.where(field_name => value)
      when :boolean
        scope.where(field_name => value == 'true')
      when :date_range
        if value.is_a?(Hash)
          start_date = value[:start]
          end_date = value[:end]
          scope = scope.where("#{field_name} >= ?", start_date) if start_date.present?
          scope = scope.where("#{field_name} <= ?", end_date) if end_date.present?
        end
        scope
      when :number_range
        if value.is_a?(Hash)
          min_val = value[:min]
          max_val = value[:max]
          scope = scope.where("#{field_name} >= ?", min_val) if min_val.present?
          scope = scope.where("#{field_name} <= ?", max_val) if max_val.present?
        end
        scope
      else
        # Unknown filter type, log warning and default to exact match
        Rails.logger.warn("Unknown filter type: #{filter_config[:type]}")
        scope.where(field_name => value)
      end
    end

    # === FIELD FORMATTING ===
    def format_field_value(record, field_name)
      field_config = resource_fields[field_name.to_s]
      return record.public_send(field_name) unless field_config

      case field_config[:type]
      when :has_many_count
        association = field_config[:options][:association]
        record.public_send(association).count
      when :belongs_to_name
        association = field_config[:options][:association]
        related_record = record.public_send(association)
        return nil unless related_record

        display_field = field_config[:options][:display_field] || :name
        related_record.public_send(display_field)
      when :currency
        number_to_currency(record.public_send(field_name))
      when :percentage
        number_to_percentage(record.public_send(field_name))
      when :date
        record.public_send(field_name)&.strftime('%Y-%m-%d')
      when :datetime
        record.public_send(field_name)&.strftime('%Y-%m-%d %H:%M')
      when :boolean
        record.public_send(field_name) ? 'Yes' : 'No'
      when :badge
        value = record.public_send(field_name)
        color_map = field_config[:options][:color_map] || {}
        { value: value, color: color_map[value.to_sym] || :gray }
      else
        record.public_send(field_name)
      end
    end

    # === AUTHORIZATION ===
    def can?(action, resource, current_user)
      permissions_config = resource_permissions[action.to_s]
      return true unless permissions_config # Default allow if no permissions defined

      roles = permissions_config[:roles]
      condition = permissions_config[:condition]

      # Check roles
      if roles.present?
        user_roles = current_user.respond_to?(:roles) ? current_user.roles : []
        return false unless roles.intersect?(user_roles)
      end

      # Check custom condition
      return condition.call(resource, current_user) if condition.respond_to?(:call)

      true
    end

    # === AUTO-DETECTION ===
    def auto_detect_filters
      return {} unless model

      filters = {}

      # Add filters for string fields
      model.columns.select { |c| c.type == :string }.each do |column|
        filters[column.name] = { type: :string }
      end

      # Add filters for boolean fields
      model.columns.select { |c| c.type == :boolean }.each do |column|
        filters[column.name] = { type: :boolean }
      end

      # Add filters for date fields
      date_types = [:date, :datetime].freeze
      model.columns.select { |c| date_types.include?(c.type) }.each do |column|
        filters[column.name] = { type: :date_range }
      end

      # Add filters for associations
      model_associations.each do |name, config|
        filters[name] = { type: :select, options: { association: true } } if config[:type] == :belongs_to
      end

      filters
    end

    def model_associations
      return {} unless model

      associations = {}
      model.reflect_on_all_associations.each do |association|
        associations[association.name] = {
          type: association.macro,
          class_name: association.class_name,
          foreign_key: association.foreign_key,
        }
      end
      associations
    end

    private

    def default_resource_title
      return 'Resources' unless model

      model_name = model.name
      return 'Resources' unless model_name

      model_name.pluralize.humanize
    end
  end
end
