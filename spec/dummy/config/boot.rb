# frozen_string_literal: true

# Set up gems listed in the Gemfile.
ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../../../../Gemfile", __dir__)

require "bundler/setup" if File.exist?(ENV["BUNDLE_GEMFILE"])

# Add engine lib to load path
$LOAD_PATH.unshift File.expand_path("../../../../lib", __dir__)

# Ensure dummy app uses its own root, not the parent qrcoge2 app
ENV["RAILS_ROOT"] = File.expand_path("..", __dir__)
