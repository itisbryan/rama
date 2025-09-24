# frozen_string_literal: true

class Rama::Resource
  include ActiveSupport::Configurable

  class_attribute :model_class_name, :fields_config, :actions_config,
                  :filters_config, :search_config, :performance_config,
                  :authorization_config

  self.fields_config = {}
  self.actions_config = {}
  self.filters_config = {}
  self.search_config = {}
  self.performance_config = {}
  self.authorization_config = {}

  class << self
    # Model configuration
    def model(model_class = nil)
      if model_class
        self.model_class_name = model_class.name
      else
        model_class_name&.constantize
      end
    end

    # Field definition DSL
    def field(name, type = :string, **options)
      self.fields_config = fields_config.merge(
        name.to_s => {
          type: type,
          options: options,
          position: fields_config.size,
        },
      )
    end

    # Action definition DSL
    def action(name, **options, &block)
      self.actions_config = actions_config.merge(
        name.to_s => {
          options: options,
          block: block,
        },
      )
    end

    # Filter definition DSL
    def filter(name, type = :string, **options)
      self.filters_config = filters_config.merge(
        name.to_s => {
          type: type,
          options: options,
        },
      )
    end

    # Search configuration DSL
    def search(**options)
      self.search_config = search_config.merge(options)
    end

    # Performance configuration DSL
    def performance(**options)
      self.performance_config = performance_config.merge(options)
    end

    # Authorization configuration DSL
    def authorize(**options)
      self.authorization_config = authorization_config.merge(options)
    end

    # Scope definition DSL
    def scope(name, scope_proc = nil, &block)
      scope_proc ||= block
      define_singleton_method("#{name}_scope") do
        scope_proc
      end
    end

    # Get configured fields
    def configured_fields
      fields_config.sort_by { |_, config| config[:position] }.to_h
    end

    # Get model associations
    def model_associations
      return {} unless model

      model.reflect_on_all_associations.each_with_object({}) do |assoc, hash|
        hash[assoc.name] = {
          type: assoc.macro,
          class_name: assoc.class_name,
          foreign_key: assoc.foreign_key,
        }
      end
    end

    # Get searchable fields
    def searchable_fields
      configured_fields.select { |_, config| config[:options][:searchable] }
    end

    # Get filterable fields
    def filterable_fields
      filters_config.presence || auto_detect_filters
    end

    private

    def auto_detect_filters
      return {} unless model

      filters = {}

      # Add filters for enum fields
      model.defined_enums.each_key do |name|
        filters[name] = { type: :select, options: { collection: model.public_send(name.pluralize) } }
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
  end

  # Instance methods
  def initialize(params = {})
    @params = params
  end

  delegate :model, to: :class

  def fields
    self.class.configured_fields
  end

  def actions
    self.class.actions_config
  end

  def filters
    self.class.filterable_fields
  end

  delegate :search_config, to: :class

  delegate :performance_config, to: :class

  delegate :authorization_config, to: :class

  # Build optimized scope
  def scope
    @scope ||= build_optimized_scope
  end

  private

  def build_optimized_scope
    base_scope = model.all

    # Apply includes for associations
    includes = detect_required_includes
    base_scope = base_scope.includes(includes) if includes.any?

    # Apply joins for count fields
    joins = detect_required_joins
    base_scope = base_scope.joins(joins) if joins.any?

    # Apply select for performance
    selects = detect_required_selects
    base_scope = base_scope.select(selects) if selects.any?

    base_scope
  end

  def detect_required_includes
    fields.filter_map do |name, config|
      case config[:type]
      when :belongs_to, :association_display
        name.to_sym
      end
    end
  end

  def detect_required_joins
    fields.filter_map do |name, config|
      case config[:type]
      when :has_many_count, :has_one_count
        name.to_sym
      end
    end
  end

  def detect_required_selects
    base_columns = ["#{model.table_name}.*"]

    # Add count columns
    count_fields = fields.select { |_, config| config[:type].to_s.end_with?('_count') }
    count_fields.each do |name, config|
      association_name = config[:options][:association] || name.to_s.gsub('_count', '').pluralize
      base_columns << "COUNT(#{association_name}.id) AS #{name}_count"
    end

    base_columns
  end
end
