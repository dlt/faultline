# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class ListErrorGroups < Base
        def self.description
          "List recent error groups, ordered by last_seen_at descending. Filter by status, free-text search, or a since timestamp."
        end

        def self.input_schema
          {
            properties: {
              status: { type: "string", enum: VALID_STATUSES, description: "Filter by status" },
              since: { type: "string", description: "ISO 8601 timestamp; only groups with last_seen_at after this are returned" },
              search: { type: "string", description: "Free-text search across exception_class, message, and file_path" },
              limit: { type: "integer", minimum: 1, maximum: 100, description: "Max number of groups to return (default 25)" }
            }
          }
        end

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
