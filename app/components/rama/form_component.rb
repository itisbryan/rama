# frozen_string_literal: true

module Rama
  class FormComponent < ApplicationComponent
    attr_reader :resource, :resource_class, :fields, :url, :method
    
    def initialize(resource:, resource_class:, fields: nil, url: nil, method: nil)
      @resource = resource
      @resource_class = resource_class
      @fields = fields || resource_class.configured_fields
      @url = url || form_url
      @method = method || form_method
    end
    
    private
    
    def form_url
      if resource.persisted?
        resource
      else
        [resource_class.model.name.underscore.pluralize.to_sym]
      end
    end
    
    def form_method
      resource.persisted? ? :patch : :post
    end
    
    def field_input(form, name, config)
      field_type = Rama.find_field_type(config[:type])
      field_instance = field_type.new(name, config[:options], resource_class)
      
      case field_instance.form_input_type
      when :text_field
        form.text_field name, class: input_classes, **field_html_options(config)
      when :text_area
        form.text_area name, class: input_classes, rows: 4, **field_html_options(config)
      when :email_field
        form.email_field name, class: input_classes, **field_html_options(config)
      when :number_field
        form.number_field name, class: input_classes, **field_html_options(config)
      when :date_field
        form.date_field name, class: input_classes, **field_html_options(config)
      when :datetime_local_field
        form.datetime_local_field name, class: input_classes, **field_html_options(config)
      when :check_box
        content_tag :div, class: "flex items-center" do
          concat form.check_box(name, class: "h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded")
          concat form.label(name, field_label(name, config), class: "ml-2 block text-sm text-gray-900")
        end
      when :select
        options = select_options(field_instance, config)
        form.select name, options, 
                   { prompt: "Select #{name.humanize}" }, 
                   { class: input_classes, **field_html_options(config) }
      when :file_field
        form.file_field name, class: input_classes, **field_html_options(config)
      when :rich_text_area
        form.rich_text_area name, class: input_classes, **field_html_options(config)
      else
        form.text_field name, class: input_classes, **field_html_options(config)
      end
    end
    
    def field_html_options(config)
      options = {}
      options[:required] = true if config[:options][:required]
      options[:placeholder] = config[:options][:placeholder] if config[:options][:placeholder]
      options[:data] = config[:options][:data] if config[:options][:data]
      options
    end
    
    def select_options(field_instance, config)
      if field_instance.respond_to?(:collection)
        collection = field_instance.collection
        
        if collection.respond_to?(:map)
          if collection.first.respond_to?(:id)
            # ActiveRecord collection
            collection.map { |item| [item.public_send(field_instance.display_attribute), item.id] }
          else
            # Array or hash collection
            collection.is_a?(Hash) ? collection.invert : collection
          end
        else
          collection
        end
      else
        config[:options][:collection] || []
      end
    end
    
    def field_label(name, config)
      config[:options][:label] || name.to_s.humanize
    end
    
    def field_help_text(config)
      config[:options][:help_text]
    end
    
    def field_errors(name)
      return unless resource.errors[name].any?
      
      content_tag :div, class: "mt-1" do
        resource.errors[name].map do |error|
          content_tag :p, error, class: "text-sm text-red-600"
        end.join.html_safe
      end
    end
    
    def form_actions
      content_tag :div, class: "flex justify-end space-x-3" do
        concat link_to("Cancel", :back, 
                      class: button_classes(variant: :secondary),
                      data: { turbo_frame: "_top" })
        concat content_tag(:button, submit_button_text, 
                          type: "submit",
                          class: button_classes(variant: :primary),
                          data: { disable_with: "Saving..." })
      end
    end
    
    def submit_button_text
      if resource.persisted?
        "Update #{resource_class.model.name}"
      else
        "Create #{resource_class.model.name}"
      end
    end
  end
end
