# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class GetErrorGroup < Base
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
