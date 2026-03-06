# frozen_string_literal: true

require "rails/generators"

module Faultline
  module Generators
    class DatabaseGenerator < Rails::Generators::Base
      source_root File.expand_path("templates", __dir__)

      desc "Configure Faultline to use a dedicated database"

      class_option :database_key, type: :string, default: "faultline",
                   desc: "The database key to use in database.yml"

      def show_database_yml_instructions
        database_key = options[:database_key]
        app_name = Rails.application.class.module_parent_name.underscore

        say ""
        say "=" * 60, :green
        say " Dedicated Database Setup for Faultline", :green
        say "=" * 60, :green
        say ""
        say "Step 1: Add the following to your config/database.yml", :yellow
        say ""
        say "For each environment (development, test, production), add:", :cyan
        say ""
        say <<~YAML, :white
          #{database_key}:
            <<: *default
            database: #{app_name}_#{database_key}_<%= Rails.env %>
        YAML
        say ""
        say "Example for PostgreSQL:", :cyan
        say ""
        say <<~YAML, :white
          development:
            primary:
              <<: *default
              database: #{app_name}_development
            #{database_key}:
              <<: *default
              database: #{app_name}_#{database_key}_development

          test:
            primary:
              <<: *default
              database: #{app_name}_test
            #{database_key}:
              <<: *default
              database: #{app_name}_#{database_key}_test

          production:
            primary:
              <<: *default
              database: #{app_name}_production
            #{database_key}:
              <<: *default
              database: #{app_name}_#{database_key}_production
        YAML
      end

      def update_initializer
        database_key = options[:database_key]
        initializer_path = "config/initializers/faultline.rb"

        unless File.exist?(initializer_path)
          say ""
          say "Warning: #{initializer_path} not found.", :red
          say "Run 'rails generate faultline:install' first.", :yellow
          return
        end

        inject_into_file initializer_path,
          after: "Faultline.configure do |config|\n" do
          <<~RUBY
            # Use a dedicated database for Faultline tables.
            # Requires adding '#{database_key}:' section to config/database.yml
            config.database_key = :#{database_key}

          RUBY
        end

        say ""
        say "Step 2: Updated #{initializer_path}", :green
      end

      def show_next_steps
        database_key = options[:database_key]

        say ""
        say "Step 3: Create and migrate the database", :yellow
        say ""
        say "  rails db:create:#{database_key}", :cyan
        say "  rails db:migrate:#{database_key}", :cyan
        say ""
        say "=" * 60, :green
        say ""
        say "If you have existing Faultline data in your primary database,", :yellow
        say "you can copy it using:", :yellow
        say ""
        say "  rails faultline:db:copy_data", :cyan
        say ""
        say "=" * 60, :green
      end
    end
  end
end
