# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Faultline::McpController", type: :request do
  let(:token) { "test-mcp-token" }
  let(:rpc_headers) do
    {
      "Authorization"  => "Bearer #{token}",
      "Content-Type"   => "application/json",
      "Accept"         => "application/json, text/event-stream"
    }
  end

  before do
    allow(Faultline.configuration).to receive(:mcp_enabled).and_return(true)
    allow(Faultline.configuration).to receive(:mcp_tokens).and_return([token])
    allow(Faultline.configuration).to receive(:mcp_readonly).and_return(true)
    Faultline::Mcp.reset_transport!
  end

  describe "POST /faultline/mcp" do
    context "when mcp_enabled is false" do
      before { allow(Faultline.configuration).to receive(:mcp_enabled).and_return(false) }

      it "returns 404" do
        post "/faultline/mcp", headers: { "Authorization" => "Bearer #{token}" }
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
        post "/faultline/mcp", headers: { "Authorization" => "Bearer wrong-token" }
        expect(response).to have_http_status(:unauthorized)
      end

      it "returns 401 even when token differs only in length" do
        post "/faultline/mcp", headers: { "Authorization" => "Bearer #{token}-longer" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "when no tokens are configured" do
      before { allow(Faultline.configuration).to receive(:mcp_tokens).and_return([]) }

      it "rejects all requests" do
        post "/faultline/mcp", headers: { "Authorization" => "Bearer #{token}" }
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "JSON-RPC dispatch with valid auth" do
      it "lists all configured tools via tools/list" do
        post "/faultline/mcp",
          params: rpc_body(id: 1, method: "tools/list", params: {}),
          headers: rpc_headers

        expect(response).to have_http_status(:ok)
        body = parse_rpc_response(response)
        names = body.dig("result", "tools").map { |t| t["name"] }
        expect(names).to match_array(Faultline::Mcp::TOOLS.keys)
      end

      it "advertises descriptions and input schemas for each tool" do
        post "/faultline/mcp",
          params: rpc_body(id: 1, method: "tools/list", params: {}),
          headers: rpc_headers

        body = parse_rpc_response(response)
        tools = body.dig("result", "tools")
        list_groups = tools.find { |t| t["name"] == "list_error_groups" }
        expect(list_groups["description"]).to be_a(String).and(satisfy { |s| s.length > 10 })
        expect(list_groups.dig("inputSchema", "properties")).to include("status", "limit")
      end

      it "dispatches tools/call to a read-only tool and returns its JSON result" do
        create(:error_group, exception_class: "RuntimeError")

        post "/faultline/mcp",
          params: rpc_body(id: 2, method: "tools/call", params: {
            name: "list_error_groups",
            arguments: { limit: 5 }
          }),
          headers: rpc_headers

        expect(response).to have_http_status(:ok)
        body = parse_rpc_response(response)
        text = body.dig("result", "content", 0, "text")
        decoded = JSON.parse(text)
        expect(decoded["count"]).to eq(1)
        expect(decoded["groups"].first["exception_class"]).to eq("RuntimeError")
      end

      it "blocks mutating tools when mcp_readonly is true and surfaces the error in the response" do
        group = create(:error_group, status: "unresolved")

        post "/faultline/mcp",
          params: rpc_body(id: 3, method: "tools/call", params: {
            name: "resolve_error_group",
            arguments: { id: group.id }
          }),
          headers: rpc_headers

        body = parse_rpc_response(response)
        text = body.dig("result", "content", 0, "text")
        decoded = JSON.parse(text)
        expect(decoded["error"]).to match(/mcp_readonly is true/)
        expect(body.dig("result", "isError")).to be(true)
        expect(group.reload.status).to eq("unresolved")
      end

      it "executes mutating tools when mcp_readonly is false" do
        allow(Faultline.configuration).to receive(:mcp_readonly).and_return(false)
        Faultline::Mcp.reset_transport!
        group = create(:error_group, status: "unresolved")

        post "/faultline/mcp",
          params: rpc_body(id: 4, method: "tools/call", params: {
            name: "resolve_error_group",
            arguments: { id: group.id }
          }),
          headers: rpc_headers

        body = parse_rpc_response(response)
        text = body.dig("result", "content", 0, "text")
        decoded = JSON.parse(text)
        expect(decoded["resolved"]).to be(true)
        expect(group.reload.status).to eq("resolved")
      end
    end
  end

  def rpc_body(method:, id:, params: {})
    { jsonrpc: "2.0", id: id, method: method, params: params }.to_json
  end

  def parse_rpc_response(response)
    raw = response.body.to_s
    if response.headers["Content-Type"].to_s.include?("text/event-stream")
      data_line = raw.lines.find { |l| l.start_with?("data:") }
      JSON.parse(data_line.sub(/^data:\s*/, ""))
    else
      JSON.parse(raw)
    end
  end
end
