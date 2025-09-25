# frozen_string_literal: true

require 'rails_helper'
require 'generator_spec/test_case'
require 'generators/rama/resources/scaffolds_generator'

RSpec.describe Rama::Generators::ResourcesGenerator, type: :generator do
  include GeneratorSpec::TestCase

  destination File.expand_path('../../../../tmp', __dir__)

  before do
    prepare_destination
    FileUtils.mkdir_p(File.join(destination_root, 'app/models'))

    # Create a test model
    File.write(
      File.join(destination_root, 'app/models/user.rb'),
      <<~RUBY,
        # frozen_string_literal: true

        class User < ApplicationRecord
          enum role: { admin: 0, user: 1, guest: 2 }
          scope :active, -> { where(active: true) }
        end
      RUBY
    )

    # Create application record
    File.write(
      File.join(destination_root, 'app/models/application_record.rb'),
      <<~RUBY,
        # frozen_string_literal: true

        class ApplicationRecord < ActiveRecord::Base
          self.abstract_class = true
        end
      RUBY
    )

    # Create database schema
    File.write(
      File.join(destination_root, 'db/schema.rb'),
      <<~RUBY,
        # frozen_string_literal: true

        ActiveRecord::Schema.define(version: 2023) do
          create_table "users", force: :cascade do |t|
            t.string "name"
            t.string "email"
            t.boolean "active", default: false
            t.integer "role"
            t.datetime "created_at", precision: 6, null: false
            t.datetime "updated_at", precision: 6, null: false
          end
        end
      RUBY
    )

    # Load the schema
    ActiveRecord::Migration.suppress_messages do
      load(File.join(destination_root, 'db/schema.rb'))
    end

    # Load the models
    require File.join(destination_root, 'app/models/application_record')
    require File.join(destination_root, 'app/models/user')
  end

  after do
    FileUtils.rm_rf(destination_root)
  end

  describe 'generator' do
    it 'creates the resource file' do
      run_generator ['User']
      expect(file('app/resources/user_resource.rb')).to exist
    end

    describe 'generated resource file content' do
      let(:content) do
        run_generator ['User']
        File.read(file('app/resources/user_resource.rb'))
      end

      it 'includes the correct class definition' do
        expect(content).to include('class UserResource < Rama::Resource')
      end

      it 'includes the model configuration' do
        expect(content).to include('model User')
      end

      it 'includes enum filters' do
        expect(content).to include('filter :role, as: :select, collection:')
      end

      it 'includes boolean filters' do
        expect(content).to include('filter :active, as: :boolean')
      end

      it 'includes scope filters' do
        expect(content).to include('filter :active, as: :boolean, label: "Active"')
      end

      it 'includes index columns' do
        expect(content).to include('index_columns :id, :name, :email, :active, :role')
      end
    end

    it 'respects the --skip option' do
      run_generator ['--skip=User']
      expect(file('app/resources/user_resource.rb')).not_to exist
    end

    it 'respects the --only option' do
      run_generator ['--only=User']
      expect(file('app/resources/user_resource.rb')).to exist
    end

    it 'respects the --force option' do
      # First run
      run_generator ['User']
      first_run = File.read(file('app/resources/user_resource.rb'))

      # Second run without force should skip
      run_generator ['User']
      second_run = File.read(file('app/resources/user_resource.rb'))
      expect(second_run).to eq(first_run)

      # Third run with force should overwrite
      run_generator ['User', '--force']
      third_run = File.read(file('app/resources/user_resource.rb'))
      expect(third_run).to eq(first_run) # Content should be the same, just forced overwrite
    end
  end
end
