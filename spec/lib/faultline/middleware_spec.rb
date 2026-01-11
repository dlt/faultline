# frozen_string_literal: true

require "rails_helper"

RSpec.describe Faultline::Middleware do
  let(:app) { ->(env) { [200, {}, ["OK"]] } }
  let(:middleware) { described_class.new(app) }
  let(:env) { Rack::MockRequest.env_for("/test", method: "GET") }

  describe "#call" do
    it "calls the app" do
      status, _headers, _body = middleware.call(env)
      expect(status).to eq(200)
    end

    it "enables TracePoint during request" do
      tracepoint_enabled = false
      app = lambda do |env|
        tracepoint_enabled = TracePoint.trace(:raise) { }.enabled?
        TracePoint.trace(:raise) { }.disable
        [200, {}, ["OK"]]
      end
      middleware = described_class.new(app)
      middleware.call(env)
      # The test passes if no error raised
    end

    context "when exception raised" do
      let(:app) { ->(_env) { raise StandardError, "Test error" } }

      before do
        allow(Faultline).to receive(:track)
        allow(Faultline.configuration).to receive(:ignored_exceptions).and_return([])
        allow(Faultline.configuration).to receive(:middleware_ignore_paths).and_return([])
        allow(Faultline.configuration).to receive(:ignored_user_agents).and_return([])
      end

      it "re-raises the exception" do
        expect { middleware.call(env) }.to raise_error(StandardError, "Test error")
      end

      it "tracks the exception" do
        expect(Faultline).to receive(:track)
        expect { middleware.call(env) }.to raise_error(StandardError)
      end

      it "clears captured locals after request" do
        expect { middleware.call(env) }.to raise_error(StandardError)
        expect(Thread.current[described_class::THREAD_LOCAL_KEY]).to be_nil
      end
    end
  end

  describe "#should_ignore?" do
    before do
      allow(Faultline.configuration).to receive(:ignored_exceptions).and_return(["ActionController::RoutingError"])
      allow(Faultline.configuration).to receive(:middleware_ignore_paths).and_return(["/health", "/assets"])
      allow(Faultline.configuration).to receive(:ignored_user_agents).and_return([/bot/i])
    end

    it "ignores configured exceptions" do
      exception = ActionController::RoutingError.new("Not found")
      result = middleware.send(:should_ignore?, exception, env)
      expect(result).to be true
    end

    it "ignores configured paths" do
      env = Rack::MockRequest.env_for("/health/check", method: "GET")
      exception = StandardError.new
      result = middleware.send(:should_ignore?, exception, env)
      expect(result).to be true
    end

    it "ignores matching user agents" do
      env = Rack::MockRequest.env_for("/test", "HTTP_USER_AGENT" => "GoogleBot")
      exception = StandardError.new
      result = middleware.send(:should_ignore?, exception, env)
      expect(result).to be true
    end

    it "does not ignore valid requests" do
      allow(Faultline.configuration).to receive(:ignored_exceptions).and_return([])
      allow(Faultline.configuration).to receive(:middleware_ignore_paths).and_return([])
      allow(Faultline.configuration).to receive(:ignored_user_agents).and_return([])
      exception = StandardError.new
      result = middleware.send(:should_ignore?, exception, env)
      expect(result).to be false
    end
  end

  describe "#extract_user" do
    before do
      allow(Faultline.configuration).to receive(:user_method).and_return(:current_user)
    end

    context "with Warden" do
      let(:user) { double("User", id: 1) }

      it "extracts user from Warden" do
        env["warden"] = double("Warden", user: user)
        result = middleware.send(:extract_user, env)
        expect(result).to eq(user)
      end
    end

    context "with controller context" do
      let(:user) { double("User", id: 1) }
      let(:controller) { double("Controller") }

      it "extracts user from controller method" do
        allow(controller).to receive(:respond_to?).with(:current_user, true).and_return(true)
        allow(controller).to receive(:current_user).and_return(user)
        env["action_controller.instance"] = controller
        result = middleware.send(:extract_user, env)
        expect(result).to eq(user)
      end
    end

    context "when extraction fails" do
      it "returns nil" do
        env["warden"] = nil
        result = middleware.send(:extract_user, env)
        expect(result).to be_nil
      end
    end
  end

  describe "#extract_custom_data" do
    let(:request) { ActionDispatch::Request.new(env) }

    context "when custom_context configured" do
      let(:custom_data) { { feature: "checkout" } }

      before do
        allow(Faultline.configuration).to receive(:custom_context).and_return(
          ->(req, env) { custom_data }
        )
      end

      it "calls custom_context lambda" do
        result = middleware.send(:extract_custom_data, env, request)
        expect(result).to eq(custom_data)
      end
    end

    context "when custom_context not configured" do
      before do
        allow(Faultline.configuration).to receive(:custom_context).and_return(nil)
      end

      it "returns empty hash" do
        result = middleware.send(:extract_custom_data, env, request)
        expect(result).to eq({})
      end
    end

    context "when custom_context raises error" do
      before do
        allow(Faultline.configuration).to receive(:custom_context).and_return(
          ->(_req, _env) { raise "oops" }
        )
      end

      it "returns empty hash" do
        result = middleware.send(:extract_custom_data, env, request)
        expect(result).to eq({})
      end
    end
  end

  describe "#capture_local_variables" do
    it "stores captured locals in thread-local storage" do
      tracepoint = double("TracePoint",
        path: "/app/models/user.rb",
        lineno: 42,
        method_id: :save,
        binding: binding
      )
      middleware.send(:capture_local_variables, tracepoint)
      captured = Thread.current[described_class::THREAD_LOCAL_KEY]
      expect(captured).to be_a(Hash)
      expect(captured[:path]).to eq("/app/models/user.rb")
      expect(captured[:lineno]).to eq(42)
      expect(captured[:method_id]).to eq(:save)
    ensure
      Thread.current[described_class::THREAD_LOCAL_KEY] = nil
    end

    it "ignores gem paths" do
      tracepoint = double("TracePoint", path: "/gems/activesupport/lib/support.rb")
      middleware.send(:capture_local_variables, tracepoint)
      expect(Thread.current[described_class::THREAD_LOCAL_KEY]).to be_nil
    end

    it "ignores ruby internal paths" do
      tracepoint = double("TracePoint", path: "/ruby/3.2.0/lib/stdlib.rb")
      middleware.send(:capture_local_variables, tracepoint)
      expect(Thread.current[described_class::THREAD_LOCAL_KEY]).to be_nil
    end

    it "ignores internal paths starting with <" do
      tracepoint = double("TracePoint", path: "<internal:marshal>")
      middleware.send(:capture_local_variables, tracepoint)
      expect(Thread.current[described_class::THREAD_LOCAL_KEY]).to be_nil
    end
  end

  describe "#clear_captured_locals" do
    it "clears thread-local storage" do
      Thread.current[described_class::THREAD_LOCAL_KEY] = { locals: {} }
      middleware.send(:clear_captured_locals)
      expect(Thread.current[described_class::THREAD_LOCAL_KEY]).to be_nil
    end
  end
end
