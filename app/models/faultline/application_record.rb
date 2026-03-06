# frozen_string_literal: true

module Faultline
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
    self.table_name_prefix = "faultline_"

    class << self
      def configure_database_connection!
        db_key = Faultline.configuration&.database_key
        return unless db_key

        unless database_configured?(db_key)
          Rails.logger.warn "[Faultline] Database '#{db_key}' not found in database.yml. Using primary database."
          return
        end

        connects_to database: { writing: db_key, reading: db_key }
      end

      private

      def database_configured?(key)
        configs = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env)
        configs.any? { |c| c.name.to_s == key.to_s }
      end
    end
  end
end
