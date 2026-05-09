# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class ListErrorGroups < Base
        private

        def execute
          scope = Faultline::ErrorGroup.all

          if (status = args[:status]).present?
            unless VALID_STATUSES.include?(status.to_s)
              return { error: "Invalid status. Use one of: #{VALID_STATUSES.join(', ')}." }
            end
            scope = scope.where(status: status)
          end

          if (since = parse_time(args[:since]))
            scope = scope.where("last_seen_at >= ?", since)
          end

          scope = scope.search(args[:search]) if args[:search].present?

          limit = parse_int(args[:limit], default: 25, min: 1, max: 100)
          records = scope.recent.limit(limit).to_a

          {
            groups: records.map { |g| serialize_group(g) },
            count: records.size,
            limit: limit
          }
        end
      end
    end
  end
end
