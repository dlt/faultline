# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module Faultline
  module Notifiers
    class Discord < Base
      COLOR_REOPENED = 0xF1C40F      # yellow
      COLOR_FIRST_OCCURRENCE = 0xE74C3C # red
      COLOR_REPEATED = 0xE67E22      # orange

      def initialize(webhook_url:, username: "Faultline", avatar_url: nil, mention: nil, **options)
        super(options)
        @webhook_url = webhook_url
        @username = username
        @avatar_url = avatar_url
        @mention = mention
      end

      def call(error_group, error_occurrence)
        payload = format_discord_payload(error_group, error_occurrence)
        send_webhook(payload)
      end

      private

      def format_discord_payload(error_group, error_occurrence)
        data = format_message(error_group, error_occurrence)

        fields = [
          { name: "Exception", value: data[:exception_class], inline: true },
          { name: "Occurrences", value: data[:occurrences].to_s, inline: true },
          { name: "Location", value: data[:location], inline: true }
        ]

        fields << { name: "User", value: data[:user], inline: true } if data[:user]

        if data[:url]
          fields << { name: "URL", value: "#{data[:method]} #{data[:url].to_s.truncate(80)}", inline: false }
        end

        embed = {
          title: data[:message],
          color: embed_color(error_group),
          fields: fields,
          footer: { text: data[:title] },
          timestamp: data[:timestamp]&.iso8601
        }

        if data[:reopened]
          embed[:description] = ":recycle: This error was previously resolved and has reoccurred."
        end

        payload = {
          username: @username,
          embeds: [embed]
        }

        payload[:avatar_url] = @avatar_url if @avatar_url
        payload[:content] = @mention if @mention

        payload
      end

      def embed_color(error_group)
        return COLOR_REOPENED if error_group.recently_reopened?
        return COLOR_FIRST_OCCURRENCE if error_group.occurrences_count == 1
        COLOR_REPEATED
      end

      def send_webhook(payload)
        uri = URI(@webhook_url)

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 5
        http.read_timeout = 5

        # request_uri preserves query strings (e.g. Discord's `?wait=true`),
        # which uri.path would drop.
        request = Net::HTTP::Post.new(uri.request_uri)
        request["Content-Type"] = "application/json"
        request.body = payload.to_json

        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "[Faultline::Discord] Webhook error: #{response.code} #{response.body}"
        end
      rescue => e
        Rails.logger.error "[Faultline::Discord] Failed to send: #{e.message}"
      end
    end
  end
end
