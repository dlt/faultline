# frozen_string_literal: true

require "digest"

module Faultline
  class McpController < ActionController::API
    before_action :ensure_mcp_enabled
    before_action :authenticate_token!

    def handle
      status, headers, body = Faultline::Mcp.transport.call(request.env)

      headers.each { |k, v| response.headers[k] = v }
      body_str = body.respond_to?(:each) ? body.each_with_object(+"") { |chunk, s| s << chunk.to_s } : body.to_s

      render body: body_str, status: status, content_type: response.headers["Content-Type"]
    end

    private

    def ensure_mcp_enabled
      head :not_found unless Faultline.configuration.mcp_enabled
    end

    def authenticate_token!
      provided = bearer_token
      return head :unauthorized if provided.blank?

      configured = Faultline.configuration.mcp_tokens
      return head :unauthorized if configured.empty?

      provided_digest = Digest::SHA256.digest(provided)
      match = configured.any? do |t|
        ActiveSupport::SecurityUtils.secure_compare(provided_digest, Digest::SHA256.digest(t.to_s))
      end

      head :unauthorized unless match
    end

    def bearer_token
      header = request.headers["Authorization"].to_s
      header.start_with?("Bearer ") ? header.delete_prefix("Bearer ").strip : nil
    end
  end
end
