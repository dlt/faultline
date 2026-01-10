# frozen_string_literal: true

module Faultline
  class ErrorSubscriber
    def report(error, handled:, severity:, context:, source: nil)
      return if should_ignore?(error)

      Faultline.track(error, {
        handled: handled,
        severity: severity,
        source: source,
        custom_data: context
      })
    end

    private

    def should_ignore?(error)
      config = Faultline.configuration
      config.ignored_exceptions.include?(error.class.name)
    end
  end
end
