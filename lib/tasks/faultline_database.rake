# frozen_string_literal: true

namespace :faultline do
  namespace :db do
    desc "Check Faultline database connection status"
    task status: :environment do
      db_key = Faultline.configuration.database_key

      if db_key
        puts "Faultline database key: #{db_key}"

        begin
          conn = Faultline::ApplicationRecord.connection
          puts "Connection pool: #{conn.pool.db_config.name}"
          conn.execute("SELECT 1")
          puts "Connection: OK"

          # Check if tables exist
          tables = %w[
            faultline_error_groups
            faultline_error_occurrences
            faultline_error_contexts
            faultline_request_traces
            faultline_request_profiles
          ]

          tables.each do |table|
            exists = conn.table_exists?(table)
            status = exists ? "exists" : "missing"
            puts "  #{table}: #{status}"
          end
        rescue => e
          puts "Connection: FAILED - #{e.message}"
        end
      else
        puts "Faultline is using the primary database (database_key not configured)"
      end
    end

    desc "Copy Faultline data from primary database to dedicated database"
    task copy_data: :environment do
      unless Faultline.configuration.database_key
        abort "Error: config.database_key must be set before copying data"
      end

      tables = %w[
        faultline_error_groups
        faultline_error_occurrences
        faultline_error_contexts
        faultline_request_traces
        faultline_request_profiles
      ]

      primary_conn = ActiveRecord::Base.connection
      faultline_conn = Faultline::ApplicationRecord.connection

      tables.each do |table|
        unless primary_conn.table_exists?(table)
          puts "Skipping #{table} (not found in primary database)"
          next
        end

        unless faultline_conn.table_exists?(table)
          puts "Skipping #{table} (not found in faultline database - run migrations first)"
          next
        end

        puts "Copying #{table}..."

        # Get count from primary
        count = primary_conn.select_value("SELECT COUNT(*) FROM #{table}").to_i

        if count.zero?
          puts "  No rows to copy"
          next
        end

        # Clear target table
        faultline_conn.execute("DELETE FROM #{table}")

        # Copy in batches
        batch_size = 1000
        copied = 0

        loop do
          rows = primary_conn.select_all(
            "SELECT * FROM #{table} ORDER BY id LIMIT #{batch_size} OFFSET #{copied}"
          )

          break if rows.empty?

          rows.each do |row|
            columns = row.keys.join(", ")
            values = row.values.map { |v|
              v.nil? ? "NULL" : faultline_conn.quote(v)
            }.join(", ")

            faultline_conn.execute(
              "INSERT INTO #{table} (#{columns}) VALUES (#{values})"
            )
          end

          copied += rows.length
          puts "  Copied #{copied}/#{count} rows..."

          break if copied >= count
        end

        puts "  Done: #{copied} rows copied"
      end

      puts ""
      puts "Data copy complete!"
      puts "You can now remove Faultline tables from your primary database if desired."
    end
  end
end
