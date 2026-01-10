# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"

Bundler.require(*Rails.groups)
require "faultline"

module Dummy
  class Application < Rails::Application
    # Explicitly set the root to the dummy directory
    config.root = File.expand_path("..", __dir__)

    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false

    # Don't generate system test files
    config.generators.system_tests = nil
  end
end
