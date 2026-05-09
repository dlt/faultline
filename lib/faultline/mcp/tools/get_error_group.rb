# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class GetErrorGroup < Base
        def self.description
          "Get a single error group by id, including a summary of its 10 most recent occurrences (without backtraces or locals)."
        end

        def self.input_schema
          {
            properties: {
              id: { type: "integer", description: "Error group id" }
            },
            required: ["id"]
          }
        end

        private

        def execute
          group = Faultline::ErrorGroup.find(args[:id])

          {
            group: serialize_group(group),
            recent_occurrences: group.recent_occurrences.map { |o| serialize_occurrence(o) }
          }
        end
      end
    end
  end
end
