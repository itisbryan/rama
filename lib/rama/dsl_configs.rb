# frozen_string_literal: true

module Rama
  # Configuration classes for the improved DSL
  
  class DisplayConfig
    attr_reader :fields, :model_class
    
    def initialize(model_class)
      @model_class = model_class
      @fields = {}
    end
    
    def show(name, as: :text, **options, &block)
      field_config = FieldConfig.new(name, as, **options)
      field_config.instance_eval(&block) if block_given?
      
      @fields[name.to_s] = field_config.to_h
    end
  end
  
  class FieldConfig
    attr_reader :name, :type, :options
    
    def initialize(name, type, **options)
      @name = name
      @type = type
      @options = options
    end
    
    def required(value = true)
      @options[:required] = value
    end
    
    def searchable(value = true)
      @options[:searchable] = value
    end
    
    def sortable(value = true)
      @options[:sortable] = value
    end
    
    def label(text)
      @options[:label] = text
    end
    
    def help_text(text)
      @options[:help_text] = text
    end
    
    def placeholder(text)
      @options[:placeholder] = text
    end
    
    def link_to(&block)
      @options[:link_to] = block
    end
    
    def options(collection)
      @options[:collection] = collection
    end
    
    def color_map(mapping)
      @options[:color_map] = mapping
    end
    
    def true_label(label)
      @options[:true_label] = label
    end
    
    def false_label(label)
      @options[:false_label] = label
    end
    
    def count_of(association)
      @options[:association] = association
      @type = :has_many_count
    end
    
    def validate(validation)
      @options[:validation] = validation
    end
    
    def readonly(value = true)
      @options[:readonly] = value
    end
    
    def default(value)
      @options[:default] = value
    end
    
    def to_h
      {
        type: @type,
        options: @options
      }
    end
  end
  
  class FiltersConfig
    attr_reader :filters
    
    def initialize
      @filters = {}
    end
    
    def by(field, using: :text, **options)
      @filters[field.to_s] = {
        type: using,
        options: options
      }
    end
    
    def text(*fields)
      fields.each { |field| by(field, using: :text_search) }
    end
    
    def select(field, options: [], **other_options)
      by(field, using: :select, options: options, **other_options)
    end
    
    def boolean(field, labels: {}, **options)
      by(field, using: :boolean, labels: labels, **options)
    end
    
    def date_range(field, **options)
      by(field, using: :date_range, **options)
    end
    
    def number_range(field, **options)
      by(field, using: :number_range, **options)
    end
  end
  
  class SearchConfig
    attr_reader :config
    
    def initialize
      @config = {}
    end
    
    def strategy(strategy_name)
      @config[:strategy] = strategy_name
    end
    
    def fields(*field_names)
      @config[:fields] = field_names.flatten
    end
    
    def suggestions_from(*field_names)
      @config[:suggestions_from] = field_names.flatten
    end
    
    def highlight_matches(enabled = true)
      @config[:highlight_matches] = enabled
    end
    
    def to_h
      @config
    end
  end
  
  class ActionsConfig
    attr_reader :bulk_actions, :row_actions
    
    def initialize
      @bulk_actions = {}
      @row_actions = {}
    end
    
    def bulk(name, label: nil, **options, &block)
      action_config = ActionConfig.new(name, label, **options)
      action_config.instance_eval(&block) if block_given?
      @bulk_actions[name.to_s] = action_config.to_h
    end
    
    def row(name, icon: nil, label: nil, **options, &block)
      action_config = ActionConfig.new(name, label, icon: icon, **options)
      action_config.instance_eval(&block) if block_given?
      @row_actions[name.to_s] = action_config.to_h
    end
    
    def to_h
      {
        bulk: @bulk_actions,
        row: @row_actions
      }
    end
  end
  
  class ActionConfig
    attr_reader :name, :label, :options
    
    def initialize(name, label, **options)
      @name = name
      @label = label || name.to_s.humanize
      @options = options
    end
    
    def update(attributes)
      @options[:update] = attributes
    end
    
    def success_message(message)
      @options[:success_message] = message
    end
    
    def confirm(message = true)
      @options[:confirm] = message
    end
    
    def condition(&block)
      @options[:condition] = block
    end
    
    def action(&block)
      @options[:action] = block
    end
    
    def format(format_type)
      @options[:format] = format_type
    end
    
    def fields(*field_names)
      @options[:fields] = field_names.flatten
    end
    
    def to_h
      {
        label: @label,
        options: @options
      }
    end
  end
  
  class FormsConfig
    attr_reader :forms
    
    def initialize
      @forms = {}
    end
    
    def create(&block)
      form_config = FormConfig.new(:create)
      form_config.instance_eval(&block) if block_given?
      @forms[:create] = form_config.to_h
    end
    
    def edit(&block)
      form_config = FormConfig.new(:edit)
      form_config.instance_eval(&block) if block_given?
      @forms[:edit] = form_config.to_h
    end
    
    def to_h
      @forms
    end
  end
  
  class FormConfig
    attr_reader :form_type, :fields, :sections
    
    def initialize(form_type)
      @form_type = form_type
      @fields = {}
      @sections = {}
    end
    
    def field(name, as: :text, **options)
      @fields[name.to_s] = {
        type: as,
        options: options
      }
    end
    
    def section(title, &block)
      section_config = SectionConfig.new(title)
      section_config.instance_eval(&block) if block_given?
      @sections[title] = section_config.to_h
    end
    
    def inherit_from(form_type)
      @inherit_from = form_type
    end
    
    def to_h
      {
        fields: @fields,
        sections: @sections,
        inherit_from: @inherit_from
      }.compact
    end
  end
  
  class SectionConfig
    attr_reader :title, :fields
    
    def initialize(title)
      @title = title
      @fields = {}
    end
    
    def field(name, as: :text, **options)
      @fields[name.to_s] = {
        type: as,
        options: options
      }
    end
    
    def to_h
      {
        title: @title,
        fields: @fields
      }
    end
  end
  
  class PermissionsConfig
    attr_reader :permissions
    
    def initialize
      @permissions = {}
    end
    
    def allow(action, for: nil, condition: nil)
      roles = Array(binding.local_variable_get(:for))
      @permissions[action.to_s] = {
        roles: roles,
        condition: condition
      }
    end
    
    def to_h
      @permissions
    end
  end
  
  class CustomizationConfig
    attr_reader :config
    
    def initialize
      @config = {}
    end
    
    def table_class(css_class)
      @config[:table_class] = css_class
    end
    
    def row_class(&block)
      @config[:row_class] = block
    end
    
    def stimulus_controller(controller_name)
      @config[:stimulus_controller] = controller_name
    end
    
    def partial(name, path)
      @config[:partials] ||= {}
      @config[:partials][name] = path
    end
    
    def to_h
      @config
    end
  end
end
