# frozen_string_literal: true

module Faultline
  class Middleware
    THREAD_LOCAL_KEY = :faultline_captured_locals

    def initialize(app)
      @app = app
    end

    def call(env)
      with_local_variable_capture do
        @app.call(env)
      end
    rescue Exception => exception
      track_exception(exception, env)
      raise
    ensure
      clear_captured_locals
    end

    private

    def with_local_variable_capture
      tracepoint = TracePoint.new(:raise) do |tp|
        capture_local_variables(tp)
      end

      tracepoint.enable { yield }
    end

    def capture_local_variables(tp)
      # Only capture from app code, not from gems
      path = tp.path.to_s
      return if path.include?("/gems/") || path.include?("/ruby/")
      return if path.start_with?("<") # internal Ruby paths like <internal:

      binding = tp.binding
      return unless binding

      locals = {}
      binding.local_variables.each do |var|
        locals[var] = binding.local_variable_get(var)
      rescue StandardError
        locals[var] = "[Error accessing variable]"
      end

      # Store the captured locals - we keep only the most recent capture
      # since re-raises will capture again
      Thread.current[THREAD_LOCAL_KEY] = {
        locals: locals,
        path: path,
        lineno: tp.lineno,
        method_id: tp.method_id
      }
    rescue StandardError => e
      Rails.logger.debug "[Faultline] Failed to capture locals: #{e.message}"
    end

    def captured_locals
      data = Thread.current[THREAD_LOCAL_KEY]
      return nil unless data

      VariableSerializer.serialize(data[:locals])
    end

    def clear_captured_locals
      Thread.current[THREAD_LOCAL_KEY] = nil
    end

    def track_exception(exception, env)
      return if should_ignore?(exception, env)

      request = ActionDispatch::Request.new(env)

      context = {
        request: request,
        user: extract_user(env),
        custom_data: extract_custom_data(env, request),
        local_variables: captured_locals
      }

      Faultline.track(exception, context)
    rescue => e
      Rails.logger.error "[Faultline] Middleware tracking failed: #{e.message}"
    end

    def should_ignore?(exception, env)
      config = Faultline.configuration

      # Check ignored exceptions
      return true if config.ignored_exceptions.include?(exception.class.name)

      # Check ignored paths
      path = env["PATH_INFO"].to_s
      return true if config.middleware_ignore_paths.any? { |p| path.start_with?(p) }

      # Check ignored user agents
      user_agent = env["HTTP_USER_AGENT"].to_s
      return true if config.ignored_user_agents.any? { |pattern| user_agent.match?(pattern) }

      false
    end

    def extract_user(env)
      config = Faultline.configuration

      # Try Warden (Devise)
      if env["warden"]&.user
        return env["warden"].user
      end

      # Try controller context
      if env["action_controller.instance"]
        controller = env["action_controller.instance"]
        method = config.user_method

        if method && controller.respond_to?(method, true)
          return controller.send(method)
        end
      end

      nil
    rescue => e
      Rails.logger.debug "[Faultline] Could not extract user: #{e.message}"
      nil
    end

    def extract_custom_data(env, request)
      config = Faultline.configuration

      if config.custom_context
        config.custom_context.call(request, env)
      else
        {}
      end
    rescue => e
      Rails.logger.debug "[Faultline] Could not extract custom data: #{e.message}"
      {}
    end
  end
end
