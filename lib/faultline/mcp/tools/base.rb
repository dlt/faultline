# frozen_string_literal: true

module Faultline
  module Mcp
    module Tools
      class Base
        VALID_STATUSES = %w[unresolved resolved ignored].freeze

        class << self
          def call(args = {})
            new(args).call
          end

          def mutates?
            false
          end
        end

        def initialize(args = {})
          @args = symbolize(args)
        end

        def call
          if self.class.mutates? && Faultline.configuration.mcp_readonly
            return { error: "Tool disabled: mcp_readonly is true. Set mcp_readonly = false to allow mutations." }
          end

          execute
        rescue ActiveRecord::RecordNotFound => e
          { error: e.message }
        rescue ArgumentError => e
          { error: e.message }
        end

        private

        attr_reader :args

        def execute
          raise NotImplementedError, "#{self.class.name} must implement #execute"
        end

        def symbolize(hash)
          (hash || {}).each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
        end

        def parse_time(value)
          return nil if value.nil? || value.to_s.strip.empty?

          Time.iso8601(value.to_s)
        rescue ArgumentError
          nil
        end

        def parse_int(value, default:, min: 1, max: 100)
          (value || default).to_i.clamp(min, max)
        end

        def parse_bool(value)
          return false if value.nil?
          return value if value == true || value == false
          %w[true 1 yes].include?(value.to_s.downcase)
        end

        def serialize_group(group)
          {
            id: group.id,
            exception_class: group.exception_class,
            message: group.sanitized_message,
            file_path: group.file_path,
            line_number: group.line_number,
            method_name: group.method_name,
            status: group.status,
            occurrences_count: group.occurrences_count,
            first_seen_at: iso(group.first_seen_at),
            last_seen_at: iso(group.last_seen_at),
            resolved_at: iso(group.resolved_at),
            last_notified_at: iso(group.last_notified_at)
          }
        end

        def serialize_occurrence(occurrence, full: false)
          base = {
            id: occurrence.id,
            error_group_id: occurrence.error_group_id,
            created_at: iso(occurrence.created_at),
            request_method: occurrence.request_method,
            request_url: occurrence.request_url,
            user_identifier: occurrence.user_identifier,
            environment: occurrence.environment,
            hostname: occurrence.hostname
          }
          return base unless full

          base.merge(
            message: occurrence.message,
            backtrace: occurrence.parsed_backtrace,
            local_variables: occurrence.parsed_local_variables,
            request_params: occurrence.parsed_request_params,
            request_headers: occurrence.parsed_request_headers,
            ip_address: occurrence.ip_address,
            user_agent: occurrence.user_agent,
            session_id: occurrence.session_id,
            source_context: occurrence.source_context
          )
        end

        def serialize_trace(trace, full: false)
          base = {
            id: trace.id,
            endpoint: trace.endpoint,
            http_method: trace.http_method,
            path: trace.path,
            status: trace.status,
            duration_ms: trace.duration_ms,
            db_runtime_ms: trace.db_runtime_ms,
            view_runtime_ms: trace.view_runtime_ms,
            db_query_count: trace.db_query_count,
            has_profile: trace.has_profile?,
            created_at: iso(trace.created_at)
          }
          return base unless full

          base.merge(spans: trace.parsed_spans)
        end

        def iso(value)
          value&.iso8601
        end
      end
    end
  end
end
