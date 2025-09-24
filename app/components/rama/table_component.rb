# frozen_string_literal: true

class Rama::TableComponent < ApplicationComponent
  attr_reader :resources, :resource_class, :columns, :actions

  def initialize(resources:, resource_class:, columns: nil, actions: true)
    @resources = resources
    @resource_class = resource_class
    @columns = columns || default_columns
    @actions = actions
  end

  private

  def default_columns
    resource_class.configured_fields.first(5).to_h
  end

  def column_header(name, config)
    if config[:options][:sortable] == false
      content_tag :span, column_title(name),
                  class: 'text-left text-xs font-medium text-gray-500 uppercase tracking-wider'
    else
      link_to column_title(name),
              current_path_with_sort(name),
              data: { turbo_frame: 'resources_table' },
              class: 'text-left text-xs font-medium text-gray-500 uppercase tracking-wider hover:text-gray-700'
    end
  end

  def column_title(name)
    name.to_s.humanize
  end

  def current_path_with_sort(column)
    current_params = request.query_parameters

    direction = if current_params[:sort] == column.to_s
                  # Toggle direction
                  current_params[:direction] == 'desc' ? 'asc' : 'desc'
                else
                  'asc'
                end

    "?#{current_params.merge(sort: column, direction: direction).to_query}"
  end

  def cell_value(resource, column_name, config)
    field_type = Rama.find_field_type(config[:type])
    field_instance = field_type.new(column_name, config[:options], resource_class)

    raw_value = field_instance.display_value(resource)

    if raw_value.respond_to?(:html_safe?)
      raw_value
    else
      h(raw_value)
    end
  end

  def row_actions(resource)
    actions_html = []

    # View action
    actions_html << link_to(
      icon('eye', class: 'w-4 h-4'),
      resource,
      class: 'text-blue-600 hover:text-blue-900',
      title: 'View',
      data: { turbo_frame: 'modal' },
    )

    # Edit action
    actions_html << link_to(
      icon('edit', class: 'w-4 h-4'),
      [:edit, resource],
      class: 'text-green-600 hover:text-green-900 ml-2',
      title: 'Edit',
      data: { turbo_frame: 'modal' },
    )

    # Delete action
    actions_html << link_to(
      icon('trash', class: 'w-4 h-4'),
      resource,
      method: :delete,
      class: 'text-red-600 hover:text-red-900 ml-2',
      title: 'Delete',
      data: {
        confirm: 'Are you sure?',
        turbo_method: :delete,
      },
    )

    safe_join(actions_html)
  end

  def empty_state
    content_tag :div, class: 'text-center py-12' do
      concat content_tag(:div, icon('inbox', class: 'w-12 h-12 mx-auto text-gray-400'))
      concat content_tag(:h3, 'No records found', class: 'mt-2 text-sm font-medium text-gray-900')
      concat content_tag(:p, 'Get started by creating a new record.', class: 'mt-1 text-sm text-gray-500')
      concat link_to('Add Record', [:new, resource_class.model.name.underscore.to_sym],
                     class: button_classes(variant: :primary, size: :small),
                     data: { turbo_frame: 'modal' },)
    end
  end
end
