# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class ErrorStats < Base
        DEFAULT_PERIOD = "1d"

        def self.description
          "Time-bucketed counts of error occurrences over a period. Granularity (minute/hour/day) is auto-selected from the period."
        end

        def self.input_schema
          periods = Faultline::ErrorGroup::PERIODS.keys
          {
            properties: {
              period: {
                type: "string",
                enum: periods,
                description: "Time window (default 1d). Available: #{periods.join(', ')}"
              }
            }
          }
        end

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
