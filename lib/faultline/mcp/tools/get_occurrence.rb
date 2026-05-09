# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class GetOccurrence < Base
        def self.description
          "Get a single error occurrence by id, with full backtrace, captured local variables, filtered request params, request headers, and source context."
        end

        def self.input_schema
          {
            properties: {
              id: { type: "integer", description: "Error occurrence id" }
            },
            required: ["id"]
          }
        end

        private

        def execute
          occurrence = Faultline::ErrorOccurrence.find(args[:id])
          { occurrence: serialize_occurrence(occurrence, full: true) }
        end
      end
    end
  end
end
