# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class CreateGithubIssue < Base
        class << self
          def mutates?
            true
          end

          def description
            "Create a GitHub issue for an error group using the most recent occurrence as context. Requires github_repo and github_token to be configured. Mutating tool — disabled when mcp_readonly is true."
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
          unless Faultline.configuration.github_configured?
            return { error: "GitHub is not configured. Set github_repo and github_token." }
          end

          group = Faultline::ErrorGroup.find(args[:id])
          occurrence = group.recent_occurrences.first || group.error_occurrences.last

          unless occurrence
            return { error: "Error group #{group.id} has no occurrences to attach to the issue." }
          end

          result = Faultline::GithubIssueCreator.new(
            error_group: group,
            error_occurrence: occurrence
          ).create

          if result[:success]
            Rails.logger.info "[Faultline] MCP created GitHub issue ##{result[:issue_number]} for error group #{group.id}"
          end

          result
        end
      end
    end
  end
end
