# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Faultline
  module Notifiers
    class Telegram < Base
      BASE_URL = "https://api.telegram.org/bot"

      def initialize(bot_token:, chat_id:, message_thread_id: nil, **options)
        super(options)
        @bot_token = bot_token
        @chat_id = chat_id
        @message_thread_id = message_thread_id
      end

      def call(error_group, error_occurrence)
        message = format_telegram_message(error_group, error_occurrence)
        send_message(message)
      end

      private

      def format_telegram_message(error_group, error_occurrence)
        data = format_message(error_group, error_occurrence)

        lines = [
          "#{status_emoji(error_group)} <b>#{escape_html(data[:title])}</b>",
          "",
          "<b>Type:</b> <code>#{escape_html(data[:exception_class])}</code>",
          "<b>Message:</b> #{escape_html(data[:message])}"
        ]

        lines << "<b>User:</b> #{escape_html(data[:user])}" if data[:user]
        lines << "<b>Count:</b> #{data[:occurrences]}"
        lines << "<b>Time:</b> #{data[:timestamp]&.strftime('%Y-%m-%d %H:%M')}"
        lines << ""
        lines << "<b>Location:</b> #{escape_html(data[:location])}"

        if data[:url]
          lines << "<b>URL:</b> #{data[:method]} #{escape_html(data[:url].to_s.truncate(100))}"
        end

        if data[:reopened]
          lines << ""
          lines << "<i>This error was previously resolved and has reoccurred.</i>"
        end

        lines.join("\n")
      end

      def escape_html(text)
        text.to_s
          .gsub("&", "&amp;")
          .gsub("<", "&lt;")
          .gsub(">", "&gt;")
      end

      def send_message(text)
        uri = URI("#{BASE_URL}#{@bot_token}/sendMessage")

        payload = {
          chat_id: @chat_id,
          text: text,
          parse_mode: "HTML",
          disable_web_page_preview: "true"
        }
        payload[:message_thread_id] = @message_thread_id if @message_thread_id

        response = Net::HTTP.post_form(uri, payload)

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "[Faultline::Telegram] API error: #{response.body}"
        end
      rescue => e
        Rails.logger.error "[Faultline::Telegram] Failed to send: #{e.message}"
      end
    end
  end
end
