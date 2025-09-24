# frozen_string_literal: true

class Rama::ApplicationComponent < ViewComponent::Base
  include Turbo::FramesHelper
  include Turbo::StreamsHelper

  private

  def flex_admin
    Rama::Engine.routes.url_helpers
  end

  def icon(name, **options)
    options[:class] = class_names('inline-block', options[:class])

    case name.to_s
    when 'user'
      content_tag :svg, options.merge(fill: 'currentColor', viewBox: '0 0 20 20') do
        content_tag :path, '', d: 'M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z'
      end
    when 'search'
      content_tag :svg, options.merge(fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24') do
        content_tag :path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2',
                               d: 'm21 21-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z'
      end
    when 'plus'
      content_tag :svg, options.merge(fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24') do
        content_tag :path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2',
                               d: 'M12 4v16m8-8H4'
      end
    when 'edit'
      content_tag :svg, options.merge(fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24') do
        content_tag :path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2',
                               d: 'M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z'
      end
    when 'trash'
      content_tag :svg, options.merge(fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24') do
        content_tag :path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2',
                               d: 'M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16'
      end
    when 'filter'
      content_tag :svg, options.merge(fill: 'none', stroke: 'currentColor', viewBox: '0 0 24 24') do
        content_tag :path, '', 'stroke-linecap': 'round', 'stroke-linejoin': 'round', 'stroke-width': '2',
                               d: 'M3 4a1 1 0 011-1h16a1 1 0 011 1v2.586a1 1 0 01-.293.707l-6.414 6.414a1 1 0 00-.293.707V17l-4 4v-6.586a1 1 0 00-.293-.707L3.293 7.207A1 1 0 013 6.5V4z'
      end
    else
      content_tag :span, name, options
    end
  end

  def button_classes(variant: :primary, size: :medium, **options)
    base_classes = 'inline-flex items-center justify-center font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2'

    variant_classes = case variant
                      when :primary
                        'bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500'
                      when :secondary
                        'bg-gray-200 text-gray-900 hover:bg-gray-300 focus:ring-gray-500'
                      when :danger
                        'bg-red-600 text-white hover:bg-red-700 focus:ring-red-500'
                      when :success
                        'bg-green-600 text-white hover:bg-green-700 focus:ring-green-500'
                      else
                        'bg-gray-100 text-gray-700 hover:bg-gray-200 focus:ring-gray-500'
                      end

    size_classes = case size
                   when :small
                     'px-3 py-1.5 text-sm'
                   when :medium
                     'px-4 py-2 text-sm'
                   when :large
                     'px-6 py-3 text-base'
                   end

    class_names(base_classes, variant_classes, size_classes, options[:class])
  end

  def card_classes(**options)
    base_classes = 'bg-white shadow rounded-lg'
    class_names(base_classes, options[:class])
  end

  def input_classes(**options)
    base_classes = 'block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm'
    class_names(base_classes, options[:class])
  end

  def badge_classes(variant: :default, **options)
    base_classes = 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium'

    variant_classes = case variant
                      when :success
                        'bg-green-100 text-green-800'
                      when :warning
                        'bg-yellow-100 text-yellow-800'
                      when :danger
                        'bg-red-100 text-red-800'
                      when :info
                        'bg-blue-100 text-blue-800'
                      else
                        'bg-gray-100 text-gray-800'
                      end

    class_names(base_classes, variant_classes, options[:class])
  end
end
