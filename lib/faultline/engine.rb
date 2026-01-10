# frozen_string_literal: true

module Faultline
  class Engine < ::Rails::Engine
    isolate_namespace Faultline

    config.generators do |g|
      g.test_framework :rspec
      g.assets false
      g.helper true
    end

    initializer "faultline.configure", before: :load_config_initializers do
      Faultline.configure {} unless Faultline.configuration
    end

    initializer "faultline.middleware", after: :load_config_initializers do |app|
      if Faultline.configuration&.enable_middleware
        app.middleware.use Faultline::Middleware
      end
    end

    initializer "faultline.error_subscriber", after: :load_config_initializers do
      if Faultline.configuration&.register_error_subscriber
        Rails.error.subscribe(Faultline::ErrorSubscriber.new)
      end
    end

    config.after_initialize do
      if Faultline.configuration&.authenticate_with.nil? && Rails.env.production?
        Rails.logger.warn "[Faultline] No authentication configured. Dashboard is publicly accessible."
      end
    end
  end
end
