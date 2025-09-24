# frozen_string_literal: true

module Rama
  class BulkOperationJob < ApplicationJob
    queue_as :flex_admin_bulk_operations
    
    def perform(operation_type, resource_class_name, filters, operation_params, user_id)
      @operation_type = operation_type
      @resource_class = resource_class_name.constantize
      @filters = filters
      @operation_params = operation_params
      @user_id = user_id
      @processed_count = 0
      @error_count = 0
      @errors = []
      
      Rails.logger.info "Starting bulk #{operation_type} for #{resource_class_name}"
      
      case operation_type.to_sym
      when :update
        perform_bulk_update
      when :delete
        perform_bulk_delete
      when :export
        perform_bulk_export
      else
        raise ArgumentError, "Unknown operation type: #{operation_type}"
      end
      
      notify_completion
      
    rescue => e
      Rails.logger.error "Bulk operation failed: #{e.message}"
      notify_error(e)
      raise
    end
    
    private
    
    def perform_bulk_update
      scope = build_filtered_scope
      update_attributes = @operation_params[:attributes]
      
      scope.find_in_batches(batch_size: 1000) do |batch|
        batch.each do |record|
          begin
            record.update!(update_attributes)
            @processed_count += 1
          rescue => e
            @error_count += 1
            @errors << { id: record.id, error: e.message }
          end
        end
        
        # Update progress
        update_progress
      end
    end
    
    def perform_bulk_delete
      scope = build_filtered_scope
      
      scope.find_in_batches(batch_size: 1000) do |batch|
        batch.each do |record|
          begin
            record.destroy!
            @processed_count += 1
          rescue => e
            @error_count += 1
            @errors << { id: record.id, error: e.message }
          end
        end
        
        update_progress
      end
    end
    
    def perform_bulk_export
      scope = build_filtered_scope
      export_format = @operation_params[:format] || 'csv'
      
      case export_format.to_sym
      when :csv
        export_to_csv(scope)
      when :xlsx
        export_to_xlsx(scope)
      when :json
        export_to_json(scope)
      else
        raise ArgumentError, "Unsupported export format: #{export_format}"
      end
    end
    
    def export_to_csv(scope)
      require 'csv'
      
      filename = "#{@resource_class.name.underscore}_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.csv"
      file_path = Rails.root.join('tmp', filename)
      
      CSV.open(file_path, 'w') do |csv|
        # Write headers
        headers = export_columns
        csv << headers
        
        # Write data in batches
        scope.find_in_batches(batch_size: 1000) do |batch|
          batch.each do |record|
            row = headers.map { |header| record.public_send(header) }
            csv << row
            @processed_count += 1
          end
          
          update_progress
        end
      end
      
      # Store file reference and notify user
      store_export_file(file_path, filename)
    end
    
    def export_to_xlsx(scope)
      require 'axlsx'
      
      filename = "#{@resource_class.name.underscore}_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.xlsx"
      file_path = Rails.root.join('tmp', filename)
      
      package = Axlsx::Package.new
      workbook = package.workbook
      
      workbook.add_worksheet(name: @resource_class.name.pluralize) do |sheet|
        # Add headers
        headers = export_columns
        sheet.add_row headers
        
        # Add data in batches
        scope.find_in_batches(batch_size: 1000) do |batch|
          batch.each do |record|
            row = headers.map { |header| record.public_send(header) }
            sheet.add_row row
            @processed_count += 1
          end
          
          update_progress
        end
      end
      
      package.serialize(file_path)
      store_export_file(file_path, filename)
    end
    
    def export_to_json(scope)
      filename = "#{@resource_class.name.underscore}_export_#{Time.current.strftime('%Y%m%d_%H%M%S')}.json"
      file_path = Rails.root.join('tmp', filename)
      
      File.open(file_path, 'w') do |file|
        file.write('[')
        first_record = true
        
        scope.find_in_batches(batch_size: 1000) do |batch|
          batch.each do |record|
            file.write(',') unless first_record
            file.write(record.to_json)
            first_record = false
            @processed_count += 1
          end
          
          update_progress
        end
        
        file.write(']')
      end
      
      store_export_file(file_path, filename)
    end
    
    def build_filtered_scope
      scope = @resource_class.all
      
      @filters.each do |key, value|
        next if value.blank?
        
        case key
        when 'search'
          scope = apply_search_filter(scope, value)
        else
          scope = apply_attribute_filter(scope, key, value)
        end
      end
      
      scope
    end
    
    def apply_search_filter(scope, query)
      # Use the search engine for consistent search behavior
      search_engine = Rama::SearchEngine.new(scope.model, query)
      search_engine.search
    end
    
    def apply_attribute_filter(scope, attribute, value)
      if value.is_a?(Hash)
        # Range filter
        scope = scope.where("#{attribute} >= ?", value[:min]) if value[:min].present?
        scope = scope.where("#{attribute} <= ?", value[:max]) if value[:max].present?
        scope
      else
        scope.where(attribute => value)
      end
    end
    
    def export_columns
      @export_columns ||= @operation_params[:columns] || default_export_columns
    end
    
    def default_export_columns
      # Get the first few columns, excluding timestamps and internal fields
      @resource_class.column_names.reject do |name|
        %w[created_at updated_at encrypted_password reset_password_token].include?(name)
      end.first(10)
    end
    
    def update_progress
      # Broadcast progress update via ActionCable
      ActionCable.server.broadcast(
        "bulk_operation_#{job_id}",
        {
          processed_count: @processed_count,
          error_count: @error_count,
          status: 'processing'
        }
      )
    end
    
    def notify_completion
      message = {
        processed_count: @processed_count,
        error_count: @error_count,
        errors: @errors.first(10), # Limit error details
        status: 'completed'
      }
      
      # Broadcast completion
      ActionCable.server.broadcast("bulk_operation_#{job_id}", message)
      
      # Send email notification if configured
      if @user_id && user = User.find_by(id: @user_id)
        BulkOperationMailer.operation_completed(user, @operation_type, message).deliver_now
      end
      
      Rails.logger.info "Bulk #{@operation_type} completed: #{@processed_count} processed, #{@error_count} errors"
    end
    
    def notify_error(error)
      message = {
        error: error.message,
        status: 'failed'
      }
      
      ActionCable.server.broadcast("bulk_operation_#{job_id}", message)
      
      if @user_id && user = User.find_by(id: @user_id)
        BulkOperationMailer.operation_failed(user, @operation_type, error).deliver_now
      end
    end
    
    def store_export_file(file_path, filename)
      # Store file reference in database or cloud storage
      # This is a simplified version - in production you'd want to use Active Storage
      export_record = BulkExport.create!(
        filename: filename,
        file_path: file_path,
        user_id: @user_id,
        resource_type: @resource_class.name,
        record_count: @processed_count,
        status: 'completed'
      )
      
      # Notify user that export is ready
      ActionCable.server.broadcast(
        "bulk_operation_#{job_id}",
        {
          export_id: export_record.id,
          download_url: "/admin/exports/#{export_record.id}/download",
          status: 'export_ready'
        }
      )
    end
  end
end
