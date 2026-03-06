# frozen_string_literal: true

module Faultline
  class Tracker
    class << self
      def track(exception, context = {})
        return nil unless should_track?(exception, context)

        config = Faultline.configuration

        # Before track callback
        if config.before_track
          result = config.before_track.call(exception, context)
          return nil if result == false
        end

        # Create or update error group
        fingerprint_context = build_fingerprint_context(exception, context)
        error_group = ErrorGroup.find_or_create_from_exception(exception, fingerprint_context: fingerprint_context)

        # Create occurrence
        occurrence = ErrorOccurrence.create_from_exception!(
          exception,
          error_group: error_group,
          request: context[:request],
          user: context[:user],
          custom_data: context[:custom_data] || {},
          local_variables: context[:local_variables]
        )

        # Reload to pick up counter cache increment from occurrence creation,
        # so occurrences_count is accurate for notification threshold checks.
        error_group.reload

        # Notify if needed
        if should_notify?(error_group, occurrence)
          Faultline.notify(error_group, occurrence)
        end

        # After track callback
        config.after_track&.call(error_group, occurrence)

        occurrence
      rescue => e
        Rails.logger.error "[Faultline] Tracking failed: #{e.message}"
        Rails.logger.error e.backtrace.first(10).join("\n")
        nil
      end

      private

      def should_track?(exception, context)
        config = Faultline.configuration

        # Check if exception class is ignored
        return false if config.ignored_exceptions.include?(exception.class.name)

        # Check user agent if request is present
        if context[:request]
          user_agent = context[:request].user_agent.to_s
          return false if config.ignored_user_agents.any? { |pattern| user_agent.match?(pattern) }
        end

        # Check if tables exist
        return false unless tables_exist?

        true
      end

      def tables_exist?
        # Cache the result: table existence is checked on every track call,
        # so avoid a schema lookup on every request once we know tables are present.
        # The ivar is never reset in production; in tests reset via
        #   Faultline::Tracker.instance_variable_set(:@tables_exist, nil)
        return @tables_exist if instance_variable_defined?(:@tables_exist)

        @tables_exist = Faultline::ApplicationRecord.connection.table_exists?("faultline_error_groups")
      rescue
        false
      end

      def build_fingerprint_context(exception, context)
        config = Faultline.configuration

        if config.custom_fingerprint
          config.custom_fingerprint.call(exception, context)
        else
          {}
        end
      end

      def should_notify?(error_group, occurrence)
        config = Faultline.configuration
        rules = config.notification_rules

        return false unless rules[:notify_in_environments].include?(Rails.env)
        return false if config.notifiers.empty?

        # Check cooldown (rate limiting)
        if config.notification_cooldown && error_group.last_notified_at
          return false if error_group.last_notified_at > config.notification_cooldown.ago
        end

        # First occurrence
        return true if rules[:on_first_occurrence] && error_group.occurrences_count == 1

        # Reopened error
        return true if rules[:on_reopen] && error_group.recently_reopened?

        # Threshold notification
        return true if rules[:on_threshold]&.include?(error_group.occurrences_count)

        # Critical exception
        return true if rules[:critical_exceptions]&.include?(error_group.exception_class)

        false
      end
    end
  end
end
