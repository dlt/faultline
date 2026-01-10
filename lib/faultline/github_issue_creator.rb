# frozen_string_literal: true

require "net/http"
require "json"

module Faultline
  class GithubIssueCreator
    GITHUB_API_URL = "https://api.github.com"

    def initialize(error_group:, error_occurrence:)
      @error_group = error_group
      @error_occurrence = error_occurrence
      @config = Faultline.configuration
    end

    def create
      return { error: "GitHub not configured" } unless configured?

      uri = URI("#{GITHUB_API_URL}/repos/#{@config.github_repo}/issues")

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{@config.github_token}"
      request["Accept"] = "application/vnd.github+json"
      request["X-GitHub-Api-Version"] = "2022-11-28"
      request["Content-Type"] = "application/json"
      request.body = issue_payload.to_json

      response = http.request(request)

      if response.code.to_i == 201
        data = JSON.parse(response.body)
        { success: true, issue_url: data["html_url"], issue_number: data["number"] }
      else
        { error: "GitHub API error: #{response.code} - #{response.body}" }
      end
    rescue => e
      { error: "Failed to create issue: #{e.message}" }
    end

    private

    def configured?
      @config.github_repo.present? && @config.github_token.present?
    end

    def issue_payload
      payload = {
        title: issue_title,
        body: issue_body,
        labels: issue_labels
      }
      payload
    end

    def issue_title
      "[Faultline] #{@error_group.exception_class}: #{@error_group.sanitized_message.truncate(80)}"
    end

    def issue_labels
      @config.github_labels || []
    end

    def issue_body
      <<~MARKDOWN
        ## Error Details

        | Field | Value |
        |-------|-------|
        | **Exception** | `#{@error_group.exception_class}` |
        | **Message** | #{@error_group.sanitized_message} |
        | **File** | `#{@error_group.file_path}:#{@error_group.line_number}` |
        | **Method** | `#{@error_group.method_name}` |
        | **Occurrences** | #{@error_group.occurrences_count} |
        | **First seen** | #{@error_group.first_seen_at} |
        | **Last seen** | #{@error_group.last_seen_at} |

        ## Stack Trace

        ```
        #{format_backtrace}
        ```

        #{local_variables_section}

        #{request_context_section}

        #{source_context_section}

        ---
        *Created by [Faultline](https://github.com/dlt/faultline)*
      MARKDOWN
    end

    def format_backtrace
      backtrace = @error_occurrence.parsed_backtrace
      return "No backtrace available" if backtrace.blank?

      backtrace.first(20).join("\n")
    end

    def local_variables_section
      return "" if @error_occurrence.local_variables.blank?

      vars = @error_occurrence.local_variables
      return "" if vars.empty?

      <<~MARKDOWN
        ## Local Variables

        These were the local variable values when the error occurred:

        ```ruby
        #{format_local_variables(vars)}
        ```
      MARKDOWN
    end

    def format_local_variables(vars, indent: 0)
      vars.map do |key, value|
        "#{' ' * indent}#{key}: #{format_value(value)}"
      end.join("\n")
    end

    def format_value(value)
      case value
      when Hash
        value.to_json
      when String
        value.length > 100 ? "#{value[0..100]}..." : value.inspect
      else
        value.inspect
      end
    end

    def request_context_section
      return "" unless @error_occurrence.respond_to?(:url) && @error_occurrence.url.present?

      <<~MARKDOWN
        ## Request Context

        | Field | Value |
        |-------|-------|
        | **URL** | `#{@error_occurrence.http_method} #{@error_occurrence.url}` |
        | **User Agent** | #{@error_occurrence.user_agent&.truncate(80)} |
        | **IP** | #{@error_occurrence.ip_address} |
      MARKDOWN
    end

    def source_context_section
      return "" unless @error_group.file_path.present?

      file_path = Rails.root.join(@error_group.file_path)
      return "" unless File.exist?(file_path)

      line_number = @error_group.line_number || 1
      lines = File.readlines(file_path)

      start_line = [line_number - 5, 1].max
      end_line = [line_number + 5, lines.length].min

      source_lines = (start_line..end_line).map do |n|
        prefix = n == line_number ? "→ " : "  "
        "#{prefix}#{n.to_s.rjust(4)}: #{lines[n - 1]}"
      end.join

      <<~MARKDOWN
        ## Source Context

        ```ruby
        #{source_lines}
        ```
      MARKDOWN
    rescue => e
      ""
    end
  end
end
