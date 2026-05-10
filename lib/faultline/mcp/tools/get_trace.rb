# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class GetTrace < Base
        def self.description
          "Get a single APM request trace by id, including all spans (SQL, view, HTTP, Redis)."
        end

        def self.input_schema
          {
            properties: {
              id: { type: "integer", description: "Request trace id" }
            },
            required: ["id"]
          }
        end

        private

        def execute
          unless Faultline.configuration.enable_apm
            return { error: "APM is disabled. Set enable_apm = true to use trace tools." }
          end

          unless Faultline::RequestTrace.table_exists_for_apm?
            return { error: "APM tables not present. Run the faultline_request_traces migration." }
          end

          trace = Faultline::RequestTrace.find(args[:id])
          { trace: serialize_trace(trace, full: true) }
        end
      end
    end
  end
end
