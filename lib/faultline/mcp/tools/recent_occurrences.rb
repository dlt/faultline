# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class RecentOccurrences < Base
        private

        def execute
          group = Faultline::ErrorGroup.find(args[:group_id])
          limit = parse_int(args[:limit], default: 25, min: 1, max: 100)

          occurrences = group.error_occurrences.recent.limit(limit).to_a

          {
            group_id: group.id,
            occurrences: occurrences.map { |o| serialize_occurrence(o) },
            count: occurrences.size,
            limit: limit
          }
        end
      end
    end
  end
end
