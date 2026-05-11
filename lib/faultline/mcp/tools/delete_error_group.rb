# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class DeleteErrorGroup < Base
        class << self
          def mutates?
            true
          end

          def description
            "Permanently delete an error group and all of its occurrences. Destructive and irreversible. Mutating tool — disabled when mcp_readonly is true."
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
          deleted_id = group.id
          occurrences_count = group.occurrences_count
          group.destroy!

          Rails.logger.info "[Faultline] MCP deleted error group #{deleted_id} (#{occurrences_count} occurrences)"

          {
            deleted: true,
            id: deleted_id,
            occurrences_deleted: occurrences_count
          }
        end
      end
    end
  end
end
