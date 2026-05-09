# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class GetTrace < Base
        private

        def execute
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
