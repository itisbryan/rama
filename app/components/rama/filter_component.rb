# frozen_string_literal: true

module Rama
  class FilterComponent < ApplicationComponent
    attr_reader :filters, :current_filters
    
    def initialize(filters:, current_filters: {})
      @filters = filters
      @current_filters = current_filters
    end
    
    private
    
    def filter_input(filter)
      case filter[:type]
      when :string, :text
        text_field_tag "filters[#{filter[:name]}]", 
                       current_filters[filter[:name]],
                       placeholder: "Search #{filter[:name].humanize}",
                       class: input_classes,
                       data: { 
                         controller: "live-filter",
                         action: "input->live-filter#filter",
                         live_filter_debounce_value: 300
                       }
      when :select
        select_tag "filters[#{filter[:name]}]",
                   options_for_select(select_options(filter), current_filters[filter[:name]]),
                   prompt: "All #{filter[:name].humanize.pluralize}",
                   class: input_classes,
                   data: { 
                     controller: "live-filter",
                     action: "change->live-filter#filter"
                   }
      when :boolean
        select_tag "filters[#{filter[:name]}]",
                   options_for_select([
                     ["All", ""],
                     ["Yes", "true"],
                     ["No", "false"]
                   ], current_filters[filter[:name]]),
                   class: input_classes,
                   data: { 
                     controller: "live-filter",
                     action: "change->live-filter#filter"
                   }
      when :date_range
        date_range_filter(filter)
      when :number_range
        number_range_filter(filter)
      else
        text_field_tag "filters[#{filter[:name]}]", 
                       current_filters[filter[:name]],
                       class: input_classes
      end
    end
    
    def date_range_filter(filter)
      current_value = current_filters[filter[:name]] || {}
      
      content_tag :div, class: "flex space-x-2" do
        concat date_field_tag("filters[#{filter[:name]}][from]", 
                             current_value[:from],
                             placeholder: "From",
                             class: input_classes,
                             data: { 
                               controller: "live-filter",
                               action: "change->live-filter#filter"
                             })
        concat date_field_tag("filters[#{filter[:name]}][to]", 
                             current_value[:to],
                             placeholder: "To",
                             class: input_classes,
                             data: { 
                               controller: "live-filter",
                               action: "change->live-filter#filter"
                             })
      end
    end
    
    def number_range_filter(filter)
      current_value = current_filters[filter[:name]] || {}
      
      content_tag :div, class: "flex space-x-2" do
        concat number_field_tag("filters[#{filter[:name]}][min]", 
                               current_value[:min],
                               placeholder: "Min",
                               class: input_classes,
                               data: { 
                                 controller: "live-filter",
                                 action: "input->live-filter#filter",
                                 live_filter_debounce_value: 500
                               })
        concat number_field_tag("filters[#{filter[:name]}][max]", 
                               current_value[:max],
                               placeholder: "Max",
                               class: input_classes,
                               data: { 
                                 controller: "live-filter",
                                 action: "input->live-filter#filter",
                                 live_filter_debounce_value: 500
                               })
      end
    end
    
    def select_options(filter)
      if filter[:options][:collection]
        collection = filter[:options][:collection]
        
        if collection.is_a?(Hash)
          collection.map { |k, v| [k.humanize, v] }
        elsif collection.respond_to?(:map) && collection.first.respond_to?(:id)
          # ActiveRecord collection
          collection.map { |item| [item.name, item.id] }
        else
          collection
        end
      else
        []
      end
    end
    
    def active_filters_count
      current_filters.values.count(&:present?)
    end
    
    def clear_filters_url
      current_url_without_filters
    end
    
    def current_url_without_filters
      params = request.query_parameters.except('filters')
      "?#{params.to_query}"
    end
    
    def filter_label(filter)
      filter[:options][:label] || filter[:name].humanize
    end
  end
end
