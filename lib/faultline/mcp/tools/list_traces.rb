# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class ListTraces < Base
        SLOW_THRESHOLD_MS = 1000

        private

        def execute
          unless Faultline.configuration.enable_apm
            return { error: "APM is disabled. Set enable_apm = true to use trace tools." }
          end

          unless Faultline::RequestTrace.table_exists_for_apm?
            return { error: "APM tables not present. Run the faultline_request_traces migration." }
          end

          since = parse_time(args[:since]) || 24.hours.ago
          limit = parse_int(args[:limit], default: 25, min: 1, max: 100)

          scope = Faultline::RequestTrace.since(since)
          scope = scope.for_endpoint(args[:endpoint]) if args[:endpoint].present?
          scope = scope.where("duration_ms >= ?", SLOW_THRESHOLD_MS) if parse_bool(args[:slow_only])

          records = scope.recent.limit(limit).to_a

          {
            traces: records.map { |t| serialize_trace(t) },
            count: records.size,
            limit: limit,
            since: iso(since),
            slow_threshold_ms: parse_bool(args[:slow_only]) ? SLOW_THRESHOLD_MS : nil
          }
        end
      end
    end
  end
end
