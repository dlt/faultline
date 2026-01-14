# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::ErrorOccurrence, type: :model do
  describe "associations" do
    it "belongs to error_group" do
      occurrence = create(:error_occurrence)
      expect(occurrence.error_group).to be_a(Faultline::ErrorGroup)
    end

    it "has many error_contexts" do
      occurrence = create(:error_occurrence)
      expect(occurrence.error_contexts).to eq([])
    end
  end

  describe "#parsed_backtrace" do
    it "parses JSON backtrace" do
      occurrence = create(:error_occurrence, backtrace: '["line1", "line2"]')
      expect(occurrence.parsed_backtrace).to eq(["line1", "line2"])
    end

    it "returns empty array for nil backtrace" do
      occurrence = build(:error_occurrence, backtrace: nil)
      expect(occurrence.parsed_backtrace).to eq([])
    end

    it "returns empty array for invalid JSON" do
      occurrence = build(:error_occurrence, backtrace: "not json")
      expect(occurrence.parsed_backtrace).to eq([])
    end
  end

  describe "#parsed_local_variables" do
    it "returns local_variables hash" do
      occurrence = create(:error_occurrence, :with_local_variables)
      expect(occurrence.parsed_local_variables).to be_a(Hash)
      expect(occurrence.parsed_local_variables["user"]).to be_present
    end

    it "returns empty hash when nil" do
      occurrence = build(:error_occurrence, local_variables: nil)
      expect(occurrence.parsed_local_variables).to eq({})
    end
  end

  describe "#app_backtrace_lines" do
    it "filters to app lines only" do
      backtrace = [
        "#{Rails.root}/app/models/user.rb:10:in `save'",
        "/gems/activerecord/lib/base.rb:100:in `save'",
        "#{Rails.root}/app/controllers/users_controller.rb:5:in `create'"
      ].to_json

      occurrence = build(:error_occurrence, backtrace: backtrace)
      app_lines = occurrence.app_backtrace_lines

      expect(app_lines.length).to eq(2)
      expect(app_lines.all? { |l| l.include?(Rails.root.to_s) }).to be true
    end
  end

  describe "#source_context" do
    it "returns nil when no app backtrace" do
      occurrence = build(:error_occurrence, backtrace: "[]")
      expect(occurrence.source_context).to be_nil
    end
  end

  describe ".recent" do
    it "orders by created_at descending" do
      old = create(:error_occurrence, created_at: 2.days.ago)
      new = create(:error_occurrence, created_at: 1.hour.ago)

      expect(described_class.recent.first).to eq(new)
    end
  end

  describe ".extract_request_data" do
    let(:request) do
      double(
        "request",
        method: "POST",
        original_url: "http://example.com/users?foo=bar",
        params: ActionController::Parameters.new(name: "John", email: "john@example.com"),
        headers: { "HTTP_ACCEPT" => "application/json", "HTTP_HOST" => "example.com" },
        user_agent: "Mozilla/5.0",
        remote_ip: "192.168.1.1",
        session: double(id: "abc123")
      )
    end

    it "extracts all request data" do
      data = described_class.extract_request_data(request)

      expect(data[:request_method]).to eq("POST")
      expect(data[:request_url]).to eq("http://example.com/users?foo=bar")
      expect(data[:user_agent]).to eq("Mozilla/5.0")
      expect(data[:ip_address]).to eq("192.168.1.1")
      expect(data[:session_id]).to eq("abc123")
    end

    it "returns empty hash when request is nil" do
      expect(described_class.extract_request_data(nil)).to eq({})
    end

    it "truncates long URLs to 2000 characters" do
      long_url = "http://example.com/" + "a" * 3000
      allow(request).to receive(:original_url).and_return(long_url)

      data = described_class.extract_request_data(request)
      expect(data[:request_url].length).to be <= 2000
    end

    it "truncates long user agents to 500 characters" do
      long_ua = "Mozilla/" + "x" * 600
      allow(request).to receive(:user_agent).and_return(long_ua)

      data = described_class.extract_request_data(request)
      expect(data[:user_agent].length).to be <= 500
    end

    it "handles nil session gracefully" do
      allow(request).to receive(:session).and_return(nil)

      data = described_class.extract_request_data(request)
      expect(data[:session_id]).to be_nil
    end

    it "handles request errors gracefully" do
      allow(request).to receive(:method).and_raise(StandardError.new("oops"))

      expect(Rails.logger).to receive(:error).with(/Failed to extract request data/)
      data = described_class.extract_request_data(request)
      expect(data).to eq({})
    end
  end

  describe ".filter_params" do
    it "returns JSON string of parameters" do
      params = ActionController::Parameters.new(name: "John", age: 30)
      result = described_class.filter_params(params)

      expect(result).to be_a(String)
      parsed = JSON.parse(result)
      expect(parsed["name"]).to eq("John")
      expect(parsed["age"]).to eq(30)
    end

    it "filters sensitive parameters" do
      params = ActionController::Parameters.new(
        name: "John",
        password: "secret123",
        password_confirmation: "secret123",
        token: "abc123",
        api_key: "key123"
      )
      result = described_class.filter_params(params)
      parsed = JSON.parse(result)

      expect(parsed["name"]).to eq("John")
      expect(parsed["password"]).to eq("[FILTERED]")
      expect(parsed["password_confirmation"]).to eq("[FILTERED]")
      expect(parsed["token"]).to eq("[FILTERED]")
      expect(parsed["api_key"]).to eq("[FILTERED]")
    end

    it "filters nested sensitive parameters" do
      params = ActionController::Parameters.new(
        user: { name: "John", password: "secret" },
        auth: { token: "abc123" }
      )
      result = described_class.filter_params(params)
      parsed = JSON.parse(result)

      expect(parsed["user"]["name"]).to eq("John")
      expect(parsed["user"]["password"]).to eq("[FILTERED]")
      expect(parsed["auth"]["token"]).to eq("[FILTERED]")
    end

    it "truncates params exceeding 50KB" do
      large_value = "x" * 60_000
      params = ActionController::Parameters.new(data: large_value)
      result = described_class.filter_params(params)

      expect(result.length).to be <= 50_015 # 50000 + '..."truncated"}'.length
      expect(result).to end_with('..."truncated"}')
    end

    it "returns empty JSON object on error" do
      bad_params = double("params")
      allow(bad_params).to receive(:to_unsafe_h).and_raise(StandardError.new("bad"))

      expect(Rails.logger).to receive(:error).with(/Failed to filter params/)
      result = described_class.filter_params(bad_params)
      expect(result).to eq("{}")
    end
  end

  describe ".filter_headers" do
    it "extracts only safe headers" do
      headers = {
        "HTTP_ACCEPT" => "application/json",
        "HTTP_HOST" => "example.com",
        "HTTP_AUTHORIZATION" => "Bearer secret",
        "HTTP_COOKIE" => "session=abc123",
        "CONTENT_TYPE" => "application/json"
      }
      result = described_class.filter_headers(headers)
      parsed = JSON.parse(result)

      expect(parsed["HTTP_ACCEPT"]).to eq("application/json")
      expect(parsed["HTTP_HOST"]).to eq("example.com")
      expect(parsed["CONTENT_TYPE"]).to eq("application/json")
      expect(parsed).not_to have_key("HTTP_AUTHORIZATION")
      expect(parsed).not_to have_key("HTTP_COOKIE")
    end

    it "truncates long header values to 500 characters" do
      headers = {
        "HTTP_USER_AGENT" => "x" * 600
      }
      result = described_class.filter_headers(headers)
      parsed = JSON.parse(result)

      expect(parsed["HTTP_USER_AGENT"].length).to be <= 500
    end

    it "returns empty JSON object on error" do
      bad_headers = double("headers")
      allow(bad_headers).to receive(:each).and_raise(StandardError.new("bad"))

      result = described_class.filter_headers(bad_headers)
      expect(result).to eq("{}")
    end
  end

  describe "#parsed_request_params" do
    it "parses JSON request params" do
      occurrence = build(:error_occurrence, request_params: '{"name":"John","age":30}')
      expect(occurrence.parsed_request_params).to eq({ "name" => "John", "age" => 30 })
    end

    it "returns empty hash for nil params" do
      occurrence = build(:error_occurrence, request_params: nil)
      expect(occurrence.parsed_request_params).to eq({})
    end

    it "returns empty hash for invalid JSON" do
      occurrence = build(:error_occurrence, request_params: "not json")
      expect(occurrence.parsed_request_params).to eq({})
    end
  end

  describe "#parsed_request_headers" do
    it "parses JSON request headers" do
      occurrence = build(:error_occurrence, request_headers: '{"HTTP_ACCEPT":"application/json"}')
      expect(occurrence.parsed_request_headers).to eq({ "HTTP_ACCEPT" => "application/json" })
    end

    it "returns empty hash for nil headers" do
      occurrence = build(:error_occurrence, request_headers: nil)
      expect(occurrence.parsed_request_headers).to eq({})
    end

    it "returns empty hash for invalid JSON" do
      occurrence = build(:error_occurrence, request_headers: "not json")
      expect(occurrence.parsed_request_headers).to eq({})
    end
  end

  describe "request params persistence" do
    it "saves request params to database and retrieves them" do
      error_group = create(:error_group)
      occurrence = described_class.create!(
        error_group: error_group,
        exception_class: "TestError",
        message: "Test message",
        backtrace: "[]",
        environment: "test",
        hostname: "localhost",
        process_id: "1234",
        request_method: "POST",
        request_url: "http://example.com/test",
        request_params: '{"user":{"name":"John","email":"john@example.com"}}',
        request_headers: '{"HTTP_ACCEPT":"application/json","HTTP_HOST":"example.com"}',
        ip_address: "127.0.0.1"
      )

      reloaded = described_class.find(occurrence.id)

      expect(reloaded.request_method).to eq("POST")
      expect(reloaded.request_url).to eq("http://example.com/test")
      expect(reloaded.parsed_request_params).to eq({ "user" => { "name" => "John", "email" => "john@example.com" } })
      expect(reloaded.parsed_request_headers).to eq({ "HTTP_ACCEPT" => "application/json", "HTTP_HOST" => "example.com" })
      expect(reloaded.ip_address).to eq("127.0.0.1")
    end
  end

  describe ".create_from_exception! with request context" do
    let(:error_group) { create(:error_group) }
    let(:exception) { StandardError.new("Test error") }
    let(:request) do
      double(
        "request",
        method: "POST",
        original_url: "http://example.com/api/users",
        params: ActionController::Parameters.new(
          user: { name: "Jane", password: "secret123" }
        ),
        headers: { "HTTP_ACCEPT" => "application/json", "HTTP_HOST" => "example.com" },
        user_agent: "TestAgent/1.0",
        remote_ip: "10.0.0.1",
        session: double(id: "session123")
      )
    end

    before do
      allow(exception).to receive(:backtrace).and_return(["app/test.rb:1:in `test'"])
    end

    it "captures request parameters during exception tracking" do
      occurrence = described_class.create_from_exception!(
        exception,
        error_group: error_group,
        request: request
      )

      expect(occurrence.request_method).to eq("POST")
      expect(occurrence.request_url).to eq("http://example.com/api/users")
      expect(occurrence.user_agent).to eq("TestAgent/1.0")
      expect(occurrence.ip_address).to eq("10.0.0.1")
      expect(occurrence.session_id).to eq("session123")
    end

    it "filters sensitive parameters during exception tracking" do
      occurrence = described_class.create_from_exception!(
        exception,
        error_group: error_group,
        request: request
      )

      params = occurrence.parsed_request_params
      expect(params["user"]["name"]).to eq("Jane")
      expect(params["user"]["password"]).to eq("[FILTERED]")
    end

    it "captures only safe headers during exception tracking" do
      occurrence = described_class.create_from_exception!(
        exception,
        error_group: error_group,
        request: request
      )

      headers = occurrence.parsed_request_headers
      expect(headers["HTTP_ACCEPT"]).to eq("application/json")
      expect(headers["HTTP_HOST"]).to eq("example.com")
    end
  end
end
