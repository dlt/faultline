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
require "faultline/mcp/tools/ignore_error_group"
require "faultline/mcp/tools/create_github_issue"

module Faultline
  module Mcp
    TOOLS = {
      "list_error_groups"   => Tools::ListErrorGroups,
      "get_error_group"     => Tools::GetErrorGroup,
      "get_occurrence"      => Tools::GetOccurrence,
      "recent_occurrences"  => Tools::RecentOccurrences,
      "error_stats"         => Tools::ErrorStats,
      "list_traces"         => Tools::ListTraces,
      "get_trace"           => Tools::GetTrace,
      "resolve_error_group" => Tools::ResolveErrorGroup,
      "ignore_error_group"  => Tools::IgnoreErrorGroup,
      "create_github_issue" => Tools::CreateGithubIssue
    }.freeze
  end
end
