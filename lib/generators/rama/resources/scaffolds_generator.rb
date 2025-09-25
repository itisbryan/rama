# frozen_string_literal: true

require 'rails/generators'
require 'active_support/core_ext/string/inflections'

# Generates Rama resource files for existing models
class Rama::Generators::ResourcesGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)
  class_option :skip, type: :array, default: [],
                      desc: 'Skip these models (comma separated)'
  class_option :only, type: :array, default: [],
                      desc: 'Only generate for these models (comma separated)'
  class_option :force, type: :boolean, default: false,
                       desc: 'Force overwrite existing files'

  def generate_resources
    models_to_generate = if options[:only].any?
                           options[:only].map(&:classify)
                         else
                           all_application_models - options[:skip].map(&:classify)
                         end

    models_to_generate.each do |model_name|
      model_class = model_name.constantize
      generate_resource(model_class)
    rescue NameError => _e
      say_status :error, "Could not find model: #{model_name}", :red
    end
  end

  private

  def all_application_models
    Rails.application&.eager_load!
    ActiveRecord::Base.descendants
      .reject { |model| model.abstract_class? || model.name.start_with?('ActiveRecord::') }
      .map(&:name)
  rescue StandardError => e
    say_status :error, "Error loading models: #{e.message}", :red
    []
  end

  def generate_resource(model_class)
    @model_class = model_class
    @model_name = model_class.name
    @resource_name = "#{@model_name}Resource"
    @file_path = "app/resources/#{@resource_name.underscore}.rb"

    if File.exist?(@file_path) && !options[:force]
      say_status :skip, "#{@file_path} already exists. Use --force to overwrite.", :yellow
      return
    end

    template 'resource.rb.erb', @file_path
    say_status :create, @file_path, :green
  end

  def analyze_model
    return @analysis if @analysis

    @analysis = {
      attributes: @model_class.column_names.map(&:to_sym),
      booleans: @model_class.columns.select { |c| c.type == :boolean }.map { |c| c.name.to_sym },
      enums: @model_class.respond_to?(:defined_enums) ? @model_class.defined_enums.keys.map(&:to_sym) : [],
      scopes: detect_scopes,
      associations: @model_class.reflect_on_all_associations.map { |a| { name: a.name, type: a.macro } },
      timestamps: @model_class.column_names.include?('created_at'),
    }

    @analysis[:searchable] = @analysis[:attributes] - [:id, :created_at, :updated_at]
    @analysis
  end

  def detect_scopes
    return [] unless @model_class.respond_to?(:scopes)

    @model_class.scopes.keys.map(&:to_sym)
  rescue StandardError
    []
  end

  def enum_options(enum_name)
    @model_class.send(enum_name.to_s.pluralize).keys.map { |k| "'#{k}'" }.join(', ')
  end

  def human_name(attribute)
    @model_class.human_attribute_name(attribute)
  end
end
