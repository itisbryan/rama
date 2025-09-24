# frozen_string_literal: true

require_relative 'dsl_configs'

module Rama
  class Resource
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

      # === DISPLAY FIELDS ===
      def display(&)
        config = DisplayConfig.new(model)
        config.instance_eval(&) if block_given?
        self.resource_config = resource_config.merge(fields: config.fields)
      end

      # === FILTERING ===
      def filters(&)
        config = FiltersConfig.new
        config.instance_eval(&) if block_given?
        self.resource_config = resource_config.merge(filters: config.filters)
      end

      # === SEARCH CONFIGURATION ===
      def search(&)
        config = SearchConfig.new
        config.instance_eval(&) if block_given?
        self.resource_config = resource_config.merge(search: config.to_h)
      end

      # === ACTIONS ===
      def actions(&)
        config = ActionsConfig.new
        config.instance_eval(&) if block_given?
        self.resource_config = resource_config.merge(actions: config.to_h)
      end

      # === FORMS ===
      def forms(&)
        config = FormsConfig.new
        config.instance_eval(&) if block_given?
        self.resource_config = resource_config.merge(forms: config.to_h)
      end

      # === PERFORMANCE ===
      def performance(&)
        config = PerformanceConfig.new
        config.instance_eval(&) if block_given?
        self.resource_config = resource_config.merge(performance: config.to_h)
      end

      # === PERMISSIONS ===
      def permissions(&)
        config = PermissionsConfig.new
        config.instance_eval(&) if block_given?
        self.resource_config = resource_config.merge(permissions: config.to_h)
      end

      # === CUSTOMIZATION ===
      def customize(&)
        config = CustomizationConfig.new
        config.instance_eval(&) if block_given?
        self.resource_config = resource_config.merge(customization: config.to_h)
      end

      # === HELPER METHODS ===
      def resource_title
        resource_config[:title] || model&.name&.pluralize&.humanize || 'Resources'
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
        when :text_search
          if model.connection.adapter_name.downcase.include?('postgresql')
            scope.where("#{field_name} ILIKE ?", "%#{value}%")
          else
            scope.where("#{field_name} LIKE ?", "%#{value}%")
          end
        when :select
          scope.where(field_name => value)
        when :boolean
          scope.where(field_name => value)
        when :date_range
          if value.is_a?(Hash)
            scope = scope.where("#{field_name} >= ?", value[:start]) if value[:start].present?
            scope = scope.where("#{field_name} <= ?", value[:end]) if value[:end].present?
          end
          scope
        when :number_range
          if value.is_a?(Hash)
            scope = scope.where("#{field_name} >= ?", value[:min]) if value[:min].present?
            scope = scope.where("#{field_name} <= ?", value[:max]) if value[:max].present?
          end
          scope
        else
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
          if association
            Rama::CacheManager.cache_association_count(record, association)
          else
            record.public_send(field_name)
          end
        when :datetime
          value = record.public_send(field_name)
          value&.strftime('%Y-%m-%d %H:%M')
        when :date
          value = record.public_send(field_name)
          value&.strftime('%Y-%m-%d')
        when :boolean
          value = record.public_send(field_name)
          if field_config[:options][:true_label] && value
            field_config[:options][:true_label]
          elsif field_config[:options][:false_label] && !value
            field_config[:options][:false_label]
          else
            value.to_s.humanize
          end
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

        # Check role-based permissions
        if roles.include?(:all) || roles.include?(current_user&.role&.to_sym)
          # Check additional conditions
          if condition
            case condition
            when Symbol
              send(condition, resource, current_user)
            when Proc
              condition.call(resource, current_user)
            else
              true
            end
          else
            true
          end
        else
          false
        end
      end

      # Legacy compatibility methods
      def field(name, type, **options)
        display do
          show name, as: type, **options
        end
      end

      def filter(name, type, **options)
        filters do
          by name, using: type, **options
        end
      end
    end
  end

  # Performance configuration class
  class PerformanceConfig
    attr_reader :config

    def initialize
      @config = {}
    end

    def paginate_with(strategy, **options)
      @config[:pagination] = { strategy: strategy, **options }
    end

    def includes(*associations)
      @config[:includes] = associations.flatten
    end

    def preload(*associations)
      @config[:preload] = associations.flatten
    end

    def cache_counts_for(*associations)
      @config[:cache_associations] = associations.flatten
    end

    def cache_page_for(duration)
      @config[:cache_page] = duration
    end

    def suggest_indexes(*fields)
      @config[:suggested_indexes] = fields.flatten
    end

    def to_h
      @config
    end
  end
end
