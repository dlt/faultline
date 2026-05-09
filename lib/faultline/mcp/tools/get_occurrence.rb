# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class GetOccurrence < Base
        private

        def execute
          occurrence = Faultline::ErrorOccurrence.find(args[:id])
          { occurrence: serialize_occurrence(occurrence, full: true) }
        end
      end
    end
  end
end
