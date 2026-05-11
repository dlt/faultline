# frozen_string_literal: true

require "faultline/mcp/tools/base"
require "faultline/mcp/tools/list_error_groups"
require "faultline/mcp/tools/get_error_group"
require "faultline/mcp/tools/get_occurrence"
require "faultline/mcp/tools/recent_occurrences"
require "faultline/mcp/tools/error_stats"
require "faultline/mcp/tools/list_traces"
require "faultline/mcp/tools/get_trace"
require "faultline/mcp/tools/resolve_error_group"
require "faultline/mcp/tools/unresolve_error_group"
require "faultline/mcp/tools/ignore_error_group"
require "faultline/mcp/tools/delete_error_group"
require "faultline/mcp/tools/bulk_update_error_groups"
require "faultline/mcp/tools/create_github_issue"

module Faultline
  module Mcp
    TOOLS = {
      "list_error_groups"        => Tools::ListErrorGroups,
      "get_error_group"          => Tools::GetErrorGroup,
      "get_occurrence"           => Tools::GetOccurrence,
      "recent_occurrences"       => Tools::RecentOccurrences,
      "error_stats"              => Tools::ErrorStats,
      "list_traces"              => Tools::ListTraces,
      "get_trace"                => Tools::GetTrace,
      "resolve_error_group"      => Tools::ResolveErrorGroup,
      "unresolve_error_group"    => Tools::UnresolveErrorGroup,
      "ignore_error_group"       => Tools::IgnoreErrorGroup,
      "delete_error_group"       => Tools::DeleteErrorGroup,
      "bulk_update_error_groups" => Tools::BulkUpdateErrorGroups,
      "create_github_issue"      => Tools::CreateGithubIssue
    }.freeze

    SERVER_NAME = "faultline"

    class << self
      def transport
        @transport ||= build_transport
      end

      def reset_transport!
        @transport = nil
      end

      private

      def build_transport
        require "mcp"
        require "mcp/server/transports/streamable_http_transport"
        ::MCP::Server::Transports::StreamableHTTPTransport.new(
          ::MCP::Server.new(name: SERVER_NAME, tools: build_mcp_tools),
          stateless: true
        )
      end

      def build_mcp_tools
        TOOLS.map { |name, tool| adapt_tool(name, tool) }
      end

      def adapt_tool(name, faultline_tool)
        Class.new(::MCP::Tool).tap do |klass|
          klass.tool_name(name)
          klass.description(faultline_tool.description)
          klass.input_schema(faultline_tool.input_schema)
          klass.define_singleton_method(:call) do |server_context: nil, **kwargs|
            result = faultline_tool.call(kwargs)
            errored = result.is_a?(Hash) && result.key?(:error)
            ::MCP::Tool::Response.new(
              [{ type: "text", text: result.to_json }],
              error: errored
            )
          end
        end
      end
    end
  end
end
