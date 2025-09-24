# frozen_string_literal: true

module Rama
  class ResourcesController < ApplicationController
    before_action :set_resource_class
    before_action :set_resource_instance, except: [:index, :new, :create]
    before_action :set_pagination_params, only: [:index]
    
    def index
      @resources = build_filtered_scope
                    .page(@page)
                    .per(@per_page)
      
      @total_count = @resources.total_count
      @filters = build_filters
      @search_query = params[:search]
      
      respond_to do |format|
        format.html
        format.turbo_stream do
          if params[:page].present?
            # Infinite scroll
            render turbo_stream: turbo_stream.append(
              "resources_list",
              partial: "resource_batch",
              locals: { resources: @resources }
            )
          else
            # Filter update
            render turbo_stream: turbo_stream.update(
              "resources_container",
              partial: "resources_table",
              locals: { resources: @resources }
            )
          end
        end
        format.json { render json: @resources }
      end
    end
    
    def show
      respond_to do |format|
        format.html
        format.turbo_stream
        format.json { render json: @resource }
      end
    end
    
    def new
      @resource = @resource_class.model.new
      
      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "modal_content",
            partial: "form",
            locals: { resource: @resource }
          )
        end
      end
    end
    
    def create
      @resource = @resource_class.model.new(resource_params)
      
      if @resource.save
        respond_to do |format|
          format.html { redirect_to [@resource], notice: "#{@resource_class.model.name} created successfully" }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.prepend("resources_list", partial: "resource_row", locals: { resource: @resource }),
              turbo_stream.update("modal", ""),
              turbo_stream_flash(:success, "#{@resource_class.model.name} created successfully")
            ]
          end
          format.json { render json: @resource, status: :created }
        end
      else
        respond_to do |format|
          format.html { render :new, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              "form_container",
              partial: "form",
              locals: { resource: @resource }
            )
          end
          format.json { render json: @resource.errors, status: :unprocessable_entity }
        end
      end
    end
    
    def edit
      respond_to do |format|
        format.html
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "modal_content",
            partial: "form",
            locals: { resource: @resource }
          )
        end
      end
    end
    
    def update
      if @resource.update(resource_params)
        respond_to do |format|
          format.html { redirect_to @resource, notice: "#{@resource_class.model.name} updated successfully" }
          format.turbo_stream do
            render turbo_stream: [
              turbo_stream.replace("resource_#{@resource.id}", partial: "resource_row", locals: { resource: @resource }),
              turbo_stream.update("modal", ""),
              turbo_stream_flash(:success, "#{@resource_class.model.name} updated successfully")
            ]
          end
          format.json { render json: @resource }
        end
      else
        respond_to do |format|
          format.html { render :edit, status: :unprocessable_entity }
          format.turbo_stream do
            render turbo_stream: turbo_stream.update(
              "form_container",
              partial: "form",
              locals: { resource: @resource }
            )
          end
          format.json { render json: @resource.errors, status: :unprocessable_entity }
        end
      end
    end
    
    def destroy
      @resource.destroy
      
      respond_to do |format|
        format.html { redirect_to resources_url, notice: "#{@resource_class.model.name} deleted successfully" }
        format.turbo_stream do
          render turbo_stream: [
            turbo_stream.remove("resource_#{@resource.id}"),
            turbo_stream_flash(:success, "#{@resource_class.model.name} deleted successfully")
          ]
        end
        format.json { head :no_content }
      end
    end
    
    def export
      ExportJob.perform_later(
        resource_class: @resource_class.name,
        filters: filter_params,
        user_id: current_user.id
      )
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream_flash(:info, "Export started. You'll receive an email when it's ready.")
        end
        format.json { render json: { message: "Export started" } }
      end
    end
    
    private
    
    def set_resource_class
      resource_name = params[:resource_name] || controller_name.singularize
      @resource_class = Rama.find_resource(resource_name)
      
      unless @resource_class
        raise ActionController::RoutingError, "Resource '#{resource_name}' not found"
      end
    end
    
    def set_resource_instance
      @resource = @resource_class.model.find(params[:id])
    end
    
    def set_pagination_params
      @page = params[:page]&.to_i || 1
      @per_page = [
        params[:per_page]&.to_i || Rama.config.default_per_page,
        Rama.config.max_per_page
      ].min
    end
    
    def build_filtered_scope
      scope = @resource_class.new.scope
      
      # Apply search
      if params[:search].present?
        scope = apply_search(scope, params[:search])
      end
      
      # Apply filters
      filter_params.each do |key, value|
        next if value.blank?
        scope = apply_filter(scope, key, value)
      end
      
      # Apply sorting
      if params[:sort].present?
        direction = params[:direction] == 'desc' ? :desc : :asc
        scope = scope.order(params[:sort] => direction)
      else
        scope = scope.order(created_at: :desc)
      end
      
      scope
    end
    
    def apply_search(scope, query)
      searchable_fields = @resource_class.searchable_fields
      return scope if searchable_fields.empty?
      
      conditions = searchable_fields.map do |field_name, _|
        "#{@resource_class.model.table_name}.#{field_name} ILIKE ?"
      end
      
      scope.where(conditions.join(' OR '), *(["%#{query}%"] * conditions.size))
    end
    
    def apply_filter(scope, key, value)
      filter_config = @resource_class.filterable_fields[key]
      return scope unless filter_config
      
      case filter_config[:type]
      when :select
        scope.where(key => value)
      when :date_range
        apply_date_range_filter(scope, key, value)
      when :number_range
        apply_number_range_filter(scope, key, value)
      when :boolean
        scope.where(key => value == 'true')
      else
        scope.where("#{key} ILIKE ?", "%#{value}%")
      end
    end
    
    def apply_date_range_filter(scope, key, value)
      return scope unless value.is_a?(Hash)
      
      scope = scope.where("#{key} >= ?", value[:from]) if value[:from].present?
      scope = scope.where("#{key} <= ?", value[:to]) if value[:to].present?
      scope
    end
    
    def apply_number_range_filter(scope, key, value)
      return scope unless value.is_a?(Hash)
      
      scope = scope.where("#{key} >= ?", value[:min]) if value[:min].present?
      scope = scope.where("#{key} <= ?", value[:max]) if value[:max].present?
      scope
    end
    
    def build_filters
      @resource_class.filterable_fields.map do |name, config|
        {
          name: name,
          type: config[:type],
          options: config[:options],
          value: filter_params[name]
        }
      end
    end
    
    def resource_params
      # This would be dynamically built based on the resource configuration
      params.require(@resource_class.model.name.underscore.to_sym).permit!
    end
    
    def filter_params
      params.permit(@resource_class.filterable_fields.keys)
    end
  end
end
