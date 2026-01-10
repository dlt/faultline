# frozen_string_literal: true

module Faultline
  class ErrorGroup < ApplicationRecord
    has_many :error_occurrences, class_name: "Faultline::ErrorOccurrence", dependent: :destroy
    has_many :recent_occurrences, -> { order(created_at: :desc).limit(10) },
             class_name: "Faultline::ErrorOccurrence"

    scope :unresolved, -> { where(status: "unresolved") }
    scope :resolved, -> { where(status: "resolved") }
    scope :ignored, -> { where(status: "ignored") }
    scope :recent, -> { order(last_seen_at: :desc) }
    scope :frequent, -> { order(occurrences_count: :desc) }
    scope :recently_reopened, -> { where.not(resolved_at: nil).where("last_seen_at > resolved_at") }
    scope :search, ->(query) {
      return all if query.blank?

      sanitized_query = query.to_s.strip
      return all if sanitized_query.blank?

      if connection.adapter_name.downcase.include?("postgresql")
        # PostgreSQL: Use tsvector full-text search with prefix matching
        tsquery = sanitized_query.gsub(/[^a-zA-Z0-9\s]/, " ").split.map { |term| "#{term}:*" }.join(" & ")
        where("searchable @@ to_tsquery('simple', ?)", tsquery)
      else
        # SQLite/MySQL: Fall back to LIKE queries
        pattern = "%#{sanitized_query}%"
        where(
          "exception_class LIKE :q OR sanitized_message LIKE :q OR file_path LIKE :q",
          q: pattern
        )
      end
    }

    class << self
      def find_or_create_from_exception(exception, fingerprint_context: {})
        fingerprint = generate_fingerprint(exception, fingerprint_context)

        error_group = find_or_create_by(fingerprint: fingerprint) do |group|
          group.exception_class = exception.class.name
          group.sanitized_message = sanitize_message(exception.message)
          group.file_path, group.line_number, group.method_name = extract_location(exception)
          group.first_seen_at = Time.current
          group.last_seen_at = Time.current
          group.occurrences_count = 0
        end

        was_resolved = error_group.status == "resolved"

        if was_resolved
          Rails.logger.info "[Faultline] Reopening resolved error group #{error_group.id}: #{error_group.exception_class}"
          error_group.update!(
            status: "unresolved",
            resolved_at: nil,
            last_seen_at: Time.current
          )
        else
          error_group.update!(last_seen_at: Time.current)
        end

        error_group
      end

      def generate_fingerprint(exception, context = {})
        components = [
          exception.class.name,
          sanitize_message(exception.message),
          extract_location(exception).first(2)
        ]

        if context[:extra_components]
          components += Array(context[:extra_components])
        end

        Digest::SHA256.hexdigest(components.flatten.compact.join("::"))
      end

      def sanitize_message(message)
        return "" if message.nil?

        message
          .gsub(/\b\d+\b/, "N")
          .gsub(/\b[0-9a-f]{24}\b/i, "ID")
          .gsub(/\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b/i, "UUID")
          .gsub(/#<.*?:0x[0-9a-f]+>/, "#<Object>")
          .gsub(/\bid=\d+/i, "id=N")
      end

      def extract_location(exception)
        return [nil, nil, nil] if exception.backtrace.blank?

        app_root = Rails.root.to_s
        app_line = exception.backtrace.find { |line| line.include?(app_root) && !line.include?("/gems/") }
        app_line ||= exception.backtrace.first

        if app_line =~ /^(.+):(\d+):in `(.+)'$/
          [$1.sub(app_root + "/", ""), $2.to_i, $3]
        elsif app_line =~ /^(.+):(\d+)/
          [$1.sub(app_root + "/", ""), $2.to_i, nil]
        else
          [app_line, nil, nil]
        end
      end
    end

    def resolve!
      update!(status: "resolved", resolved_at: Time.current)
    end

    def unresolve!
      update!(status: "unresolved", resolved_at: nil)
    end

    def ignore!
      update!(status: "ignored")
    end

    def display_name
      "#{exception_class}: #{sanitized_message.truncate(100)}"
    end

    def recently_reopened?
      resolved_at.present? && last_seen_at.present? && last_seen_at > resolved_at
    end

    PERIODS = {
      "1h" => { duration: 1.hour, granularity: :minute },
      "2h" => { duration: 2.hours, granularity: :minute },
      "4h" => { duration: 4.hours, granularity: :minute },
      "1d" => { duration: 1.day, granularity: :hour },
      "2d" => { duration: 2.days, granularity: :hour },
      "1w" => { duration: 1.week, granularity: :day },
      "1m" => { duration: 1.month, granularity: :day },
      "all" => { duration: nil, granularity: :day }
    }.freeze

    def occurrences_over_time(period: "1d")
      config = PERIODS[period] || PERIODS["1d"]
      scope = error_occurrences
      scope = scope.where("created_at >= ?", config[:duration].ago) if config[:duration]

      group_expr = date_trunc_sql(config[:granularity])
      scope.group(Arel.sql(group_expr))
           .order(Arel.sql(group_expr))
           .count
    end

    def occurrences_in_range(start_time:, end_time:)
      duration = end_time - start_time

      # Auto-select granularity based on range
      granularity = if duration <= 1.hour
                      :minute
                    elsif duration <= 1.day
                      :hour
                    else
                      :day
                    end

      scope = error_occurrences.where(created_at: start_time..end_time)
      group_expr = date_trunc_sql(granularity)

      scope.group(Arel.sql(group_expr))
           .order(Arel.sql(group_expr))
           .count
    end

    private

    def date_trunc_sql(granularity)
      adapter = self.class.connection.adapter_name.downcase

      case granularity
      when :minute
        if adapter.include?("postgresql")
          "date_trunc('minute', created_at)"
        elsif adapter.include?("mysql")
          "DATE_FORMAT(created_at, '%Y-%m-%d %H:%i:00')"
        else # SQLite
          "strftime('%Y-%m-%d %H:%M:00', created_at)"
        end
      when :hour
        if adapter.include?("postgresql")
          "date_trunc('hour', created_at)"
        elsif adapter.include?("mysql")
          "DATE_FORMAT(created_at, '%Y-%m-%d %H:00:00')"
        else # SQLite
          "strftime('%Y-%m-%d %H:00:00', created_at)"
        end
      else # :day
        if adapter.include?("postgresql")
          "DATE(created_at)"
        elsif adapter.include?("mysql")
          "DATE(created_at)"
        else # SQLite
          "DATE(created_at)"
        end
      end
    end

    def increment_occurrences!
      increment!(:occurrences_count)
    end
  end
end
