# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class UnresolveErrorGroup < Base
        class << self
          def mutates?
            true
          end

          def description
            "Mark an error group as unresolved (reopen it). Clears resolved_at. Mutating tool — disabled when mcp_readonly is true."
          end

          def input_schema
            {
              properties: {
                id: { type: "integer", description: "Error group id" }
              },
              required: ["id"]
            }
          end
        end

        private

        def execute
          group = Faultline::ErrorGroup.find(args[:id])
          group.unresolve!

          Rails.logger.info "[Faultline] MCP unresolved error group #{group.id}"

          { group: serialize_group(group.reload), unresolved: true }
        end
      end
    end
  end
end
