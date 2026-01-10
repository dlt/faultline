# frozen_string_literal: true

module Faultline
  class ErrorOccurrence < ApplicationRecord
    belongs_to :error_group, class_name: "Faultline::ErrorGroup", counter_cache: :occurrences_count
    has_many :error_contexts, class_name: "Faultline::ErrorContext", dependent: :destroy

    scope :recent, -> { order(created_at: :desc) }

    class << self
      def occurrences_over_time(period: "1d")
        config = ErrorGroup::PERIODS[period] || ErrorGroup::PERIODS["1d"]
        scope = all
        scope = scope.where("created_at >= ?", config[:duration].ago) if config[:duration]

        case config[:granularity]
        when :minute
          scope.group(Arel.sql("date_trunc('minute', created_at)"))
               .order(Arel.sql("date_trunc('minute', created_at)"))
               .count
        when :hour
          scope.group(Arel.sql("date_trunc('hour', created_at)"))
               .order(Arel.sql("date_trunc('hour', created_at)"))
               .count
        else
          scope.group(Arel.sql("DATE(created_at)"))
               .order(Arel.sql("DATE(created_at)"))
               .count
        end
      end

      def create_from_exception!(exception, error_group:, request: nil, user: nil, custom_data: {}, local_variables: nil)
        occurrence = create!(
          error_group: error_group,
          exception_class: exception.class.name,
          message: exception.message,
          backtrace: format_backtrace(exception.backtrace),
          local_variables: local_variables,
          user_id: user&.id,
          user_type: user&.class&.name,
          environment: Rails.env,
          hostname: Socket.gethostname,
          process_id: Process.pid.to_s,
          **extract_request_data(request)
        )

        custom_data.each do |key, value|
          occurrence.error_contexts.create!(
            key: key.to_s,
            value: value.is_a?(String) ? value : value.to_json
          )
        end

        occurrence
      end

      def format_backtrace(backtrace_array)
        return "[]" if backtrace_array.blank?

        limit = Faultline.configuration.backtrace_lines_limit
        backtrace_array.first(limit).to_json
      end

      def extract_request_data(request)
        return {} unless request

        {
          request_method: request.method,
          request_url: request.original_url.to_s.truncate(2000),
          request_params: filter_params(request.params),
          request_headers: filter_headers(request.headers),
          user_agent: request.user_agent.to_s.truncate(500),
          ip_address: request.remote_ip,
          session_id: request.session&.id&.to_s
        }
      rescue => e
        Rails.logger.error "[Faultline] Failed to extract request data: #{e.message}"
        {}
      end

      def filter_params(params)
        filter_fields = Faultline.configuration.resolved_filter_parameters
        filter = ActiveSupport::ParameterFilter.new(filter_fields)
        filter.filter(params.to_unsafe_h).to_json
      rescue
        "{}"
      end

      def filter_headers(headers)
        safe_headers = %w[
          HTTP_ACCEPT HTTP_ACCEPT_LANGUAGE HTTP_HOST
          HTTP_REFERER HTTP_USER_AGENT REQUEST_METHOD
          HTTP_X_FORWARDED_FOR HTTP_X_REAL_IP CONTENT_TYPE
        ]

        result = {}
        headers.each do |key, value|
          result[key] = value.to_s.truncate(500) if safe_headers.include?(key.to_s)
        end

        result.to_json
      rescue
        "{}"
      end
    end

    def user
      return nil unless user_id && user_type

      user_class = user_type.safe_constantize
      return nil unless user_class

      user_class.find_by(id: user_id)
    rescue
      nil
    end

    def user_identifier
      return nil unless user_id

      cached_user = user
      return "#{user_type}##{user_id}" unless cached_user

      [:email, :name, :username, :id].each do |method|
        return cached_user.public_send(method).to_s if cached_user.respond_to?(method)
      end

      "#{user_type}##{user_id}"
    rescue
      "User##{user_id}"
    end

    def parsed_backtrace
      JSON.parse(backtrace || "[]")
    rescue
      []
    end

    def parsed_request_params
      JSON.parse(request_params || "{}")
    rescue
      {}
    end

    def parsed_request_headers
      JSON.parse(request_headers || "{}")
    rescue
      {}
    end

    def parsed_local_variables
      local_variables || {}
    end

    def app_backtrace_lines
      parsed_backtrace.select { |line| line.include?(Rails.root.to_s) && !line.include?("/gems/") }
    end

    def source_context(context_lines: 7)
      first_app_line = app_backtrace_lines.first
      return nil unless first_app_line

      match = first_app_line.match(/^(.+):(\d+):in/)
      return nil unless match

      file_path = match[1]
      line_number = match[2].to_i

      return nil unless File.exist?(file_path)

      lines = File.readlines(file_path)
      start_line = [line_number - context_lines, 1].max
      end_line = [line_number + context_lines, lines.length].min

      {
        file_path: file_path.sub(Rails.root.to_s + "/", ""),
        line_number: line_number,
        start_line: start_line,
        lines: (start_line..end_line).map { |n| { number: n, code: lines[n - 1]&.chomp || "", current: n == line_number } }
      }
    rescue
      nil
    end
  end
end
