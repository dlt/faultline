# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class BulkUpdateErrorGroups < Base
        VALID_ACTIONS = %w[resolve unresolve ignore delete].freeze

        class << self
          def mutates?
            true
          end

          def description
            "Apply the same action (resolve/unresolve/ignore/delete) to many error groups at once. Mutating tool — disabled when mcp_readonly is true."
          end

          def input_schema
            {
              properties: {
                ids: {
                  type: "array",
                  items: { type: "integer" },
                  description: "Error group ids to act on (must be non-empty)"
                },
                action: {
                  type: "string",
                  enum: VALID_ACTIONS,
                  description: "Action to apply to every id"
                }
              },
              required: ["ids", "action"]
            }
          end
        end

        private

        def execute
          ids = Array(args[:ids]).map { |id| Integer(id) rescue nil }.compact
          return { error: "ids must be a non-empty array of integers." } if ids.empty?

          action = args[:action].to_s
          unless VALID_ACTIONS.include?(action)
            return { error: "Invalid action. Use one of: #{VALID_ACTIONS.join(', ')}." }
          end

          scope = Faultline::ErrorGroup.where(id: ids)
          matched_ids = scope.pluck(:id)
          missing_ids = ids - matched_ids

          affected = apply(scope, action)

          Rails.logger.info "[Faultline] MCP bulk #{action} on #{affected} error groups (ids: #{matched_ids.join(', ')})"

          {
            action: action,
            affected: affected,
            ids: matched_ids,
            missing_ids: missing_ids
          }
        end

        def apply(scope, action)
          case action
          when "resolve"
            scope.update_all(status: "resolved", resolved_at: Time.current, updated_at: Time.current)
          when "unresolve"
            scope.update_all(status: "unresolved", resolved_at: nil, updated_at: Time.current)
          when "ignore"
            scope.update_all(status: "ignored", updated_at: Time.current)
          when "delete"
            count = scope.count
            scope.destroy_all
            count
          end
        end
      end
    end
  end
end
