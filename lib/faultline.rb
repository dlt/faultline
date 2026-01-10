# frozen_string_literal: true

require "faultline/version"
require "faultline/configuration"
require "faultline/engine"
require "faultline/tracker"
require "faultline/middleware"
require "faultline/error_subscriber"
require "faultline/variable_serializer"
require "faultline/notifiers/base"
require "faultline/notifiers/telegram"
require "faultline/notifiers/slack"
require "faultline/notifiers/webhook"
require "faultline/notifiers/resend"

module Faultline
  class << self
    attr_accessor :configuration

    def configure
      self.configuration ||= Configuration.new
      yield(configuration) if block_given?
      configuration
    end

    def track(exception, context = {})
      Tracker.track(exception, context)
    end

    def notify(error_group, error_occurrence)
      return unless configuration.notifiers.any?

      configuration.notifiers.each do |notifier|
        next unless notifier.should_notify?(error_group, error_occurrence)
        notifier.call(error_group, error_occurrence)
      rescue => e
        Rails.logger.error "[Faultline] Notifier #{notifier.class.name} failed: #{e.message}"
      end

      # Update last_notified_at for rate limiting
      error_group.update_column(:last_notified_at, Time.current)
    rescue => e
      Rails.logger.error "[Faultline] Notification delivery failed: #{e.message}"
    end

    def reset_configuration!
      self.configuration = Configuration.new
    end
  end
end
