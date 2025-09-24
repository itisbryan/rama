# frozen_string_literal: true

class FlexAdmin::Generators::InstallGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  desc 'Install FlexAdmin in your Rails application'

  class_option :skip_migrations, type: :boolean, default: false,
                                 desc: 'Skip generating migrations'

  class_option :skip_initializer, type: :boolean, default: false,
                                  desc: 'Skip generating initializer'

  class_option :skip_routes, type: :boolean, default: false,
                             desc: 'Skip adding routes'

  def create_initializer
    return if options[:skip_initializer]

    template 'initializer.rb', 'config/initializers/flex_admin.rb'
    say 'Created FlexAdmin initializer', :green
  end

  def create_migrations
    return if options[:skip_migrations]

    migration_template 'create_flex_admin_tables.rb',
                       'db/migrate/create_flex_admin_tables.rb'
    say 'Created FlexAdmin migrations', :green
  end

  def add_routes
    return if options[:skip_routes]

    route 'mount FlexAdmin::Engine => "/admin", as: :flex_admin'
    say 'Added FlexAdmin routes', :green
  end

  def create_admin_directory
    empty_directory 'app/admin'
    create_file 'app/admin/.keep'
    say 'Created app/admin directory', :green
  end

  def create_sample_resource
    template 'sample_resource.rb', 'app/admin/user_resource.rb'
    say 'Created sample User resource', :green
  end

  def configure_application
    application_config = <<~CONFIG

      # FlexAdmin configuration
      config.autoload_paths += %W[\#{config.root}/app/admin]
    CONFIG

    inject_into_file 'config/application.rb',
                     application_config,
                     after: 'class Application < Rails::Application'

    say 'Updated application configuration', :green
  end

  def install_javascript_dependencies
    if File.exist?('package.json')
      run 'npm install sortablejs'
      say 'Installed JavaScript dependencies', :green
    else
      say 'Skipping JavaScript dependencies (no package.json found)', :yellow
    end
  end

  def setup_solid_suite
    if rails_8_or_higher?
      say 'Rails 8 detected - Solid suite will be configured automatically', :green
    else
      say 'Rails 7 detected - consider upgrading to Rails 8 for Solid suite benefits', :yellow
    end
  end

  def show_post_install_message
    say "\n#{'=' * 60}", :green
    say 'FlexAdmin has been successfully installed!', :green
    say '=' * 60, :green
    say "\nNext steps:", :cyan
    say '1. Run migrations: rails db:migrate', :white
    say '2. Configure authentication in config/initializers/flex_admin.rb', :white
    say '3. Create admin resources in app/admin/', :white
    say '4. Visit /admin to access your admin panel', :white
    say "\nDocumentation: https://flexadmin.dev/docs", :cyan
    say '=' * 60, :green
  end

  private

  def rails_8_or_higher?
    Rails::VERSION::MAJOR >= 8
  end
end
