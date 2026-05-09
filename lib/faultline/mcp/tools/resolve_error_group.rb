# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class ResolveErrorGroup < Base
        class << self
          def mutates?
            true
          end

          def description
            "Mark an error group as resolved. Mutating tool — disabled when mcp_readonly is true."
          end

          def input_schema
            {
              properties: {
                id: { type: "integer", description: "Error group id" },
                note: { type: "string", description: "Optional note logged with the resolution" }
              },
              required: ["id"]
            }
          end
        end

        private

        def execute
          group = Faultline::ErrorGroup.find(args[:id])
          group.resolve!

          note = args[:note].to_s
          log_msg = "[Faultline] MCP resolved error group #{group.id}"
          log_msg += " — note: #{note}" if note.present?
          Rails.logger.info(log_msg)

          { group: serialize_group(group.reload), resolved: true }
        end
      end
    end
  end
end
