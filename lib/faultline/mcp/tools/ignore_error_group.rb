# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class IgnoreErrorGroup < Base
        class << self
          def mutates?
            true
          end
        end

        private

        def execute
          group = Faultline::ErrorGroup.find(args[:id])
          group.ignore!

          Rails.logger.info "[Faultline] MCP ignored error group #{group.id}"

          { group: serialize_group(group.reload), ignored: true }
        end
      end
    end
  end
end
