# frozen_string_literal: true

module Rama
  class DashboardController < ApplicationController
    def index
      @stats = dashboard_stats
      @recent_activities = recent_activities
      @quick_actions = quick_actions
      
      respond_to do |format|
        format.html
        format.turbo_stream
      end
    end
    
    def stats
      @stats = dashboard_stats
      
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.update(
            "dashboard_stats",
            partial: "stats",
            locals: { stats: @stats }
          )
        end
        format.json { render json: @stats }
      end
    end
    
    private
    
    def dashboard_stats
      Rails.cache.fetch("flex_admin_dashboard_stats", expires_in: 5.minutes) do
        stats = {}
        
        Rama.resources.each do |name, resource_class|
          model = resource_class.model
          next unless model
          
          stats[name] = {
            total_count: model.count,
            recent_count: model.where(created_at: 1.week.ago..).count,
            name: name.humanize
          }
        end
        
        stats
      end
    end
    
    def recent_activities
      # This would be implemented based on your audit log system
      []
    end
    
    def quick_actions
      [
        {
          name: "Create User",
          url: "#",
          icon: "user-plus",
          color: "blue"
        },
        {
          name: "Export Data",
          url: "#",
          icon: "download",
          color: "green"
        },
        {
          name: "System Settings",
          url: "#",
          icon: "settings",
          color: "gray"
        }
      ]
    end
  end
end
