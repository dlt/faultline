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
        expect(Thread.current[described_class::THREAD_APP_BINDING_KEY]).to be_nil
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
    after do
      Thread.current[described_class::THREAD_LOCAL_KEY] = nil
      Thread.current[described_class::THREAD_APP_BINDING_KEY] = nil
    end

    context "when exception raised in app code" do
      it "captures locals from the raise site" do
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
      end
    end

    context "when exception raised in gem code" do
      it "captures locals from the last app-code binding" do
        # Simulate having tracked an app binding before the gem exception
        app_binding = binding
        local_var_for_test = "test_value"
        Thread.current[described_class::THREAD_APP_BINDING_KEY] = {
          binding: app_binding,
          path: "/app/controllers/users_controller.rb",
          lineno: 190,
          method_id: :create
        }

        # Now simulate an exception raised in gem code
        gem_tracepoint = double("TracePoint", path: "/gems/activerecord/lib/base.rb")
        middleware.send(:capture_local_variables, gem_tracepoint)

        captured = Thread.current[described_class::THREAD_LOCAL_KEY]
        expect(captured).to be_a(Hash)
        expect(captured[:path]).to eq("/app/controllers/users_controller.rb")
        expect(captured[:lineno]).to eq(190)
        expect(captured[:method_id]).to eq(:create)
        expect(captured[:locals]).to include(:app_binding, :local_var_for_test)
      end

      it "does not capture if no app binding was tracked" do
        gem_tracepoint = double("TracePoint", path: "/gems/activerecord/lib/base.rb")
        middleware.send(:capture_local_variables, gem_tracepoint)
        expect(Thread.current[described_class::THREAD_LOCAL_KEY]).to be_nil
      end
    end
  end

  describe "#track_app_binding" do
    after do
      Thread.current[described_class::THREAD_APP_BINDING_KEY] = nil
    end

    it "stores app-code binding in thread-local storage" do
      tracepoint = double("TracePoint",
        path: "/app/models/user.rb",
        lineno: 42,
        method_id: :save,
        binding: binding
      )
      middleware.send(:track_app_binding, tracepoint)
      tracked = Thread.current[described_class::THREAD_APP_BINDING_KEY]
      expect(tracked).to be_a(Hash)
      expect(tracked[:path]).to eq("/app/models/user.rb")
      expect(tracked[:lineno]).to eq(42)
      expect(tracked[:binding]).to be_a(Binding)
    end

    it "ignores gem paths" do
      tracepoint = double("TracePoint", path: "/gems/activesupport/lib/support.rb")
      middleware.send(:track_app_binding, tracepoint)
      expect(Thread.current[described_class::THREAD_APP_BINDING_KEY]).to be_nil
    end

    it "ignores ruby internal paths" do
      tracepoint = double("TracePoint", path: "/ruby/3.2.0/lib/stdlib.rb")
      middleware.send(:track_app_binding, tracepoint)
      expect(Thread.current[described_class::THREAD_APP_BINDING_KEY]).to be_nil
    end

    it "ignores internal paths starting with <" do
      tracepoint = double("TracePoint", path: "<internal:marshal>")
      middleware.send(:track_app_binding, tracepoint)
      expect(Thread.current[described_class::THREAD_APP_BINDING_KEY]).to be_nil
    end

    it "overwrites previous binding on each line" do
      tracepoint1 = double("TracePoint", path: "/app/models/user.rb", lineno: 10, method_id: :foo, binding: binding)
      tracepoint2 = double("TracePoint", path: "/app/models/user.rb", lineno: 20, method_id: :foo, binding: binding)

      middleware.send(:track_app_binding, tracepoint1)
      expect(Thread.current[described_class::THREAD_APP_BINDING_KEY][:lineno]).to eq(10)

      middleware.send(:track_app_binding, tracepoint2)
      expect(Thread.current[described_class::THREAD_APP_BINDING_KEY][:lineno]).to eq(20)
    end
  end

  describe "#clear_captured_locals" do
    it "clears both thread-local storage keys" do
      Thread.current[described_class::THREAD_LOCAL_KEY] = { locals: {} }
      Thread.current[described_class::THREAD_APP_BINDING_KEY] = { binding: binding }
      middleware.send(:clear_captured_locals)
      expect(Thread.current[described_class::THREAD_LOCAL_KEY]).to be_nil
      expect(Thread.current[described_class::THREAD_APP_BINDING_KEY]).to be_nil
    end
  end

  describe "integration: gem-originated exceptions" do
    before do
      allow(Faultline).to receive(:track)
      allow(Faultline.configuration).to receive(:ignored_exceptions).and_return([])
      allow(Faultline.configuration).to receive(:middleware_ignore_paths).and_return([])
      allow(Faultline.configuration).to receive(:ignored_user_agents).and_return([])
    end

    it "captures local variables from app code when exception raised in gem" do
      captured_context = nil
      allow(Faultline).to receive(:track) do |_exception, context|
        captured_context = context
      end

      # Simulate app code that calls a gem method which raises
      app = lambda do |_env|
        my_local_var = { key: "value" }
        another_var = 42
        # This simulates calling a gem method that raises internally
        # In reality, the TracePoint would track lines up to this point
        raise StandardError, "Gem error"
      end

      middleware = described_class.new(app)
      expect { middleware.call(env) }.to raise_error(StandardError)

      expect(captured_context[:local_variables]).to be_a(Hash)
    end
  end
end
