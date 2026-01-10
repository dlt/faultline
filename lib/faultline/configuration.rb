# frozen_string_literal: true

module Faultline
  class Configuration
    attr_accessor :user_class,
                  :user_method,
                  :account_method,
                  :ignored_exceptions,
                  :ignored_user_agents,
                  :filter_parameters,
                  :custom_fingerprint,
                  :before_track,
                  :after_track,
                  :authenticate_with,
                  :authorize_with,
                  :app_name,
                  :notifiers,
                  :notification_rules,
                  :notification_cooldown,
                  :enable_middleware,
                  :register_error_subscriber,
                  :middleware_ignore_paths,
                  :backtrace_lines_limit,
                  :sanitize_fields,
                  :retention_days

    def initialize
      @user_class = "User"
      @user_method = :current_user
      @account_method = nil
      @ignored_exceptions = [
        "ActiveRecord::RecordNotFound",
        "ActionController::RoutingError",
        "ActionController::UnknownFormat",
        "ActionController::InvalidAuthenticityToken",
        "ActionController::BadRequest"
      ]
      @ignored_user_agents = [
        /bot/i, /crawler/i, /spider/i, /Googlebot/i, /Bingbot/i, /Slurp/i
      ]
      @filter_parameters = []
      @custom_fingerprint = nil
      @before_track = nil
      @after_track = nil
      @authenticate_with = nil
      @authorize_with = nil
      @app_name = nil
      @notifiers = []
      @notification_rules = default_notification_rules
      @notification_cooldown = 5.minutes
      @enable_middleware = true
      @register_error_subscriber = false
      @middleware_ignore_paths = ["/assets", "/up", "/health", "/faultline"]
      @backtrace_lines_limit = 50
      @sanitize_fields = %w[password password_confirmation token api_key secret access_token refresh_token]
      @retention_days = 90
    end

    def add_notifier(notifier)
      @notifiers << notifier
    end

    def user_class_constant
      @user_class.constantize
    rescue NameError
      nil
    end

    def resolved_app_name
      @app_name || Rails.application.class.module_parent_name
    end

    def resolved_filter_parameters
      (@filter_parameters + Rails.application.config.filter_parameters + @sanitize_fields).uniq
    end

    private

    def default_notification_rules
      {
        on_first_occurrence: true,
        on_reopen: true,
        on_threshold: [10, 50, 100, 500, 1000],
        critical_exceptions: [],
        notify_in_environments: ["production"]
      }
    end
  end
end
