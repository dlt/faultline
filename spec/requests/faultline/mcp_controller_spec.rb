# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Faultline::McpController", type: :request do
  let(:token) { "test-mcp-token" }

  before do
    allow(Faultline.configuration).to receive(:mcp_enabled).and_return(true)
    allow(Faultline.configuration).to receive(:mcp_tokens).and_return([token])
    allow(Faultline.configuration).to receive(:mcp_readonly).and_return(true)
  end

  describe "POST /faultline/mcp" do
    context "when mcp_enabled is false" do
      before do
        allow(Faultline.configuration).to receive(:mcp_enabled).and_return(false)
      end

      it "returns 404" do
        post "/faultline/mcp", headers: auth_headers(token)
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when no Authorization header is sent" do
      it "returns 401" do
        post "/faultline/mcp"
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the Authorization header is malformed" do
      it "returns 401 for non-Bearer scheme" do
        post "/faultline/mcp", headers: { "Authorization" => "Token #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 for empty bearer value" do
        post "/faultline/mcp", headers: { "Authorization" => "Bearer " }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the token does not match" do
      it "returns 401" do
        post "/faultline/mcp", headers: auth_headers("wrong-token")
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 even when token differs only in length" do
        post "/faultline/mcp", headers: auth_headers("#{token}-longer")
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no tokens are configured" do
      before do
        allow(Faultline.configuration).to receive(:mcp_tokens).and_return([])
      end

      it "rejects all requests" do
        post "/faultline/mcp", headers: auth_headers(token)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when the token matches" do
      it "returns 200" do
        post "/faultline/mcp", headers: auth_headers(token)
        expect(response).to have_http_status(:ok)
      end

      it "returns the readonly flag in the body" do
        post "/faultline/mcp", headers: auth_headers(token)
        body = JSON.parse(response.body)
        expect(body["status"]).to eq("ok")
        expect(body["readonly"]).to be true
      end

      it "reflects readonly: false when configured" do
        allow(Faultline.configuration).to receive(:mcp_readonly).and_return(false)
        post "/faultline/mcp", headers: auth_headers(token)
        body = JSON.parse(response.body)
        expect(body["readonly"]).to be false
      end

      it "matches against any configured token" do
        allow(Faultline.configuration).to receive(:mcp_tokens).and_return(["other-token", token])
        post "/faultline/mcp", headers: auth_headers(token)
        expect(response).to have_http_status(:ok)
      end
    end
  end

  def auth_headers(t)
    { "Authorization" => "Bearer #{t}" }
  end
end
