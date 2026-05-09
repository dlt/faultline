# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class ErrorStats < Base
        DEFAULT_PERIOD = "1d"

        private

        def execute
          requested = args[:period].to_s
          period = Faultline::ErrorGroup::PERIODS.key?(requested) ? requested : DEFAULT_PERIOD
          config = Faultline::ErrorGroup::PERIODS[period]

          counts = Faultline::ErrorOccurrence.occurrences_over_time(period: period)

          {
            period: period,
            granularity: config[:granularity].to_s,
            total: counts.values.sum,
            buckets: counts.map { |bucket, count| { bucket: bucket.to_s, count: count } }
          }
        end
      end
    end
  end
end
